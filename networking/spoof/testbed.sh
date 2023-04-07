#! /bin/bash -e

hostbase='tb'
numhosts=3
firsthost=4
ntwk="1.2.3.0"
clen=24
delay=''
rate=''
loss=''
bridge='tb_bridge'
declare -a hosts
declare -a addrs

function ip_to_num {
    local ip=$1
    echo $ip | awk -F. '{ print ($1*16777216)+($2*65536)+($3*256)+$4 }'
}

function num_to_ip {
    local num=$1
    local -a quads
    for i in $(seq 3 -1 0)
    do
      quads[$i]=$(( $num & 0xFF ))
      num=$(( $num / 0x100 ))
    done
    echo "${quads[0]}.${quads[1]}.${quads[2]}.${quads[3]}"
}

while [[ $# -gt 0 ]]
do
    key="$1"; shift

    case $key in
        -c|--cidr)
            val=$1; shift
            ntwk=$(echo $val | awk -F/ '{print $1}')
            clen=$(echo $val | awk -F/ '{print $2}')
            ;;
        -n|--num-hosts)
            numhosts=$1; shift
            ;;
        -N|--first-host)
            firsthost=$1; shift
            ;;
        -b|--base-name)
            hostbase=$1; shift
            ;;
        -d|--delay)
            delay="delay $1"; shift
            ;;
        -r|--rate)
            rate="rate $1"; shift
            ;;
        -l|--loss)
            loss="loss random $1"; shift
            ;;
        -h|--help)
            echo "Usage: $0 [-c|--cidr <cidr>] [-n|--num-hosts <num-hosts>] [-N|--first-host <first-host>] [-b|--base-name <base-name>] [-d|--delay <delay>] [-r|--rate <rate>] [-l|--loss <loss>] [-h|--help]" >&2
            echo "   <cidr> is a CIDR block [default is 1.2.3.0/24]" >&2
            echo "   <num-hosts> is the number of virtual hosts to create [default is 3]" >&2
            echo "   <first-host> is the first host number within the CIDR block [default is 4 -> addresses are 1.2.3.4, 1.2.3.5, and 1.2.3.6]" >&2
            echo "   <base-name> is used to create the namespace and device names [default is tb]" >&2
            echo "   <delay> is specified in units, such as 10ms [default is 0]" >&2
            echo "   <rate> is specified in units, such as 1kbit [default is unlimited]" >&2
            echo "   <loss> is specified in percentage, such as 50 [default is 0]" >&2
            exit 0
            ;;
        *)
            echo "Unknown option $key" >&2
            ;;
    esac
done

netbase=$(ip_to_num $ntwk)

for i in $(seq 0 $(( $numhosts - 1 )))
do
    hosts[$i]="${hostbase}${i}"
    addrs[$i]="$(num_to_ip $(( $netbase + $firsthost + $i )))"
done

echo "Network is $ntwk/$clen"
echo "Host namespaces are ${hosts[*]}"
echo "Host addresses are ${addrs[*]}"

qdisc=''
if [ -n "$delay" ]
then
    qdisc="$qdisc $delay"
fi
if [ -n "$rate" ]
then
    qdisc="$qdisc $rate"
fi
if [ -n "$loss" ]
then
    qdisc="$qdisc $loss"
fi
echo "Link characteristics: $qdisc"

# Create a bridge, which will connect the other namespaces
ip netns add $bridge
ip netns exec $bridge ip link set lo up
ip netns exec $bridge ip link add name $bridge type bridge
ip netns exec $bridge ip link set dev $bridge up
ip netns exec $bridge ip addr add $ntwk/24 brd + dev $bridge

function create_namespace {
    local hnum=$1

    local h=${hosts[$hnum]}
    local a=${addrs[$hnum]}
    local bd="${bridge}_${hnum}"

    # Create a namespace
    ip netns add $h

    # Bring up the loopback link
    ip netns exec $h ip link set lo up
    # Create the virtual ethernet link

    ip link add $h type veth peer name $bd

    # Add the endpoints of the link to the namespaces
    ip link set $h netns $h
    ip link set $bd netns $bridge

    # Connect the bride-side of the link to the bridge
    ip netns exec $bridge ip link set dev $bd master $bridge

    # Set the addresses of the endpoints
    ip netns exec $h ip addr add $a/32 dev $h
    ip netns exec $bridge ip addr add $ntwk/24 dev $bd

    # Bring up both ends of the link
    ip netns exec $h ip link set $h up
    ip netns exec $bridge ip link set $bd up

    # Set up routing
    ip netns exec $h ip route add $ntwk/32 dev $h proto static scope global src $a
    ip netns exec $bridge ip route add $a/32 dev $bd proto static scope global src $ntwk
    ip netns exec $h ip route add $ntwk/$clen dev $h proto static scope global src $a

    # If necessary, set the link characteristics
    if [ -n "$qdisc" ]
    then
        # Enable queue disciplines for the links
        ip netns exec $h tc qdisc add dev $h root handle 1:0 netem
        ip netns exec $bridge tc qdisc add dev $bd root handle 1:0 netem

        # Set the link characteristics
        ip netns exec $h tc qdisc change dev $h root netem $qdisc
        ip netns exec $bridge tc qdisc change dev $bd root netem $qdisc
    fi
}

# Now create the virtual hosts
for i in $(seq 0 $(( $numhosts - 1 )))
do
    create_namespace $i
done

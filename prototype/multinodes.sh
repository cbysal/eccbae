#!/bin/bash

CHAIN_ID=12345
BLOCK_INTERVAL=12
GENESIS_TEMPLATE='{
	"config": {
		"chainId": CHAIN_ID,
		"homesteadBlock": 0,
		"eip150Block": 0,
		"eip155Block": 0,
		"eip158Block": 0,
		"byzantiumBlock": 0,
		"constantinopleBlock": 0,
		"petersburgBlock": 0,
		"istanbulBlock": 0,
		"berlinBlock": 0,
		"londonBlock": 0,
		"solo": {
			"period": BLOCK_INTERVAL
		}
	},
	"gasLimit": "5000000",
	"difficulty": "1",
	"alloc": ALLOC
}'

function config_machines {
  num=$1
  pass=$2

  sed -i 's/#\s*StrictHostKeyChecking ask/    StrictHostKeyChecking no/' /etc/ssh/ssh_config

  if [ ! -f ~/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa -q
  fi

  pids=()
  for ((i = 0; i < num; i++)); do
    sshpass -p "$pass" ssh-copy-id 192.168.1.$((101 + i)) &
    pids+=($!)
  done
  for pid in "${pids[@]}"; do
    wait "$pid"
  done

  pids=()
  for ((i = 0; i < num; i++)); do
    ssh 192.168.1.$((101 + i)) "sed -i 's/^#MaxStartups 10:30:100/MaxStartups 64:1:256/' /etc/ssh/sshd_config" &
    pids+=($!)
  done
  for pid in "${pids[@]}"; do
    wait "$pid"
  done

  pids=()
  for ((i = 0; i < num; i++)); do
    ssh 192.168.1.$((101 + i)) systemctl restart ssh.service &
    pids+=($!)
  done
  for pid in "${pids[@]}"; do
    wait "$pid"
  done
}

function gen_genesis {
  local genesis
  local accounts
  local alloc

  accounts=$(sort /geth/accounts.txt)
  alloc="{\n"
  for address in $accounts; do
    alloc="$alloc\t\t\"$address\": { \"balance\": \"0x1000000000000000000000000000\" },\n"
  done
  alloc=$(echo "$alloc" | cut -c 1-$((${#alloc} - 3)))
  alloc="$alloc\n\t}"
  alloc=$(echo -e "$alloc")

  genesis=$GENESIS_TEMPLATE
  genesis=${genesis/"CHAIN_ID"/$CHAIN_ID}
  genesis=${genesis/"BLOCK_INTERVAL"/$BLOCK_INTERVAL}
  genesis=${genesis/"ALLOC"/$alloc}

  echo "$genesis" >/geth/genesis.json
}

function init_nodes {
  local machines=$1
  local nodes_per_machine=$2
  local bandwidth=$3
  local pids

  python network.py "$machines" "$nodes_per_machine" 50 "$bandwidth"

  pids=()
  for ((i = 0; i < $((machines * nodes_per_machine)); i++)); do
    /geth/geth --datadir /geth/localnode --plainkey --password /dev/null --verbosity 2 account new &
    pids+=($!)
  done
  for pid in "${pids[@]}"; do
    wait "$pid"
  done

  accounts=$(find /geth/localnode/keystore/* | awk -F'--' '{print $3}' | sort)
  echo "$accounts" >/geth/accounts.txt
  gen_genesis

  readarray -t accounts </geth/accounts.txt
  /geth/geth --datadir /geth/localnode --verbosity 2 init genesis.json
  accounts_list=$(printf "0x%s," "${accounts[@]}")
  accounts_list=${accounts_list%,}
  /geth/geth --datadir /geth/localnode --plainkey --unlockall --password /dev/null gentxs /geth/txs /geth/native_blocks /geth/alias_blocks

  pids=()
  for ((i = 0; i < machines; i++)); do
    for ((j = 0; j < nodes_per_machine; j++)); do
      ssh 192.168.1.$((101 + i)) mkdir -p /geth/node$j/keystore &
      pids+=($!)
    done
  done
  for pid in "${pids[@]}"; do
    wait "$pid"
  done

  pids=()
  for ((i = 0; i < machines; i++)); do
    for ((j = 0; j < nodes_per_machine; j++)); do
      local id
      id=$((i * nodes_per_machine + j))
      find /geth/localnode/keystore/* -name "*${accounts[$id]}" -exec scp {} 192.168.1.$((101 + i)):/geth/node$j/keystore \; &
      pids+=($!)
    done
  done
  for pid in "${pids[@]}"; do
    wait "$pid"
  done

  pids=()
  for ((i = 0; i < machines; i++)); do
    rsync -r /geth/alias_blocks /geth/genesis.json /geth/geth /geth/native_blocks /geth/network 192.168.1.$((101 + i)):/geth &
    pids+=($!)
  done
  for pid in "${pids[@]}"; do
    wait "$pid"
  done

  pids=()
  for ((i = 0; i < machines; i++)); do
    for ((j = 0; j < nodes_per_machine; j++)); do
      ssh 192.168.1.$((101 + i)) /geth/geth --datadir /geth/node$j --verbosity 2 init /geth/genesis.json &
      pids+=($!)
    done
  done
  for pid in "${pids[@]}"; do
    wait "$pid"
  done
}

function run_nodes {
  local name=$1
  local machines=$2
  local nodes_per_machine=$3
  local protocol=$4
  local txs=$5
  local matchblock=$6
  local matchtx=$7
  local accounts

  rm -rf /geth/logs/$name
  mkdir -p /geth/logs/$name

  readarray -t accounts </geth/accounts.txt

  for ((i = 0; i < machines; i++)); do
    for ((j = 0; j < nodes_per_machine; j++)); do
      id=$((i * nodes_per_machine + j))
      if [ $id -eq 0 ]; then
        ssh 192.168.1.$((101 + i)) /geth/geth --datadir /geth/node$j --plainkey --syncmode full --port $((23000 + j)) --authrpc.port $((27000 + j)) --nodekeyhex "$(printf %064x $((id + 1)))" --maxpeers 1000 --nodiscover --nat extip:192.168.1.$((101 + i)) --unlockall --password /dev/null --mine --miner.etherbase 0x"${accounts[$id]}" --protocol "$protocol" --conn /geth/network/node$id.json --txs "$txs" --matchblock "$matchblock" --matchtx "$matchtx" 2> "/geth/logs/$name/node$id.log" &
      else
        ssh 192.168.1.$((101 + i)) /geth/geth --datadir /geth/node$j --plainkey --syncmode full --port $((23000 + j)) --authrpc.port $((27000 + j)) --nodekeyhex "$(printf %064x $((id + 1)))" --maxpeers 1000 --nodiscover --nat extip:192.168.1.$((101 + i)) --protocol "$protocol" --conn /geth/network/node$id.json --txs "$txs" --matchblock "$matchblock" --matchtx "$matchtx" 2> "/geth/logs/$name/node$id.log" &
      fi
    done
  done
}

trap "killall -q geth" EXIT

case $1 in
config)
  config_machines "$2" "$3"
  ;;
init)
  init_nodes "$2" "$3" "$4"
  ;;
run)
  run_nodes "$2" "$3" "$4" "$5" "$6" "$7" "$8"
  wait
  ;;
scalability)
  init_nodes 100 $(($2 / 100)) 10

  case $3 in
    native)
    run_nodes "$1-$2-$3" 100 "$(($2 / 100))" 68 /geth/native_blocks 1 1
    ;;
    alias)
    run_nodes "$1-$2-$3" 100 "$(($2 / 100))" 68 /geth/alias_blocks 1 1
    ;;
    bcb)
    run_nodes "$1-$2-$3" 100 "$(($2 / 100))" 69 /geth/native_blocks 0.0757 0.9044
    ;;
    eccb)
    run_nodes "$1-$2-$3" 100 "$(($2 / 100))" 70 /geth/native_blocks 0.9524 0.9044
    ;;
    aeccb)
    run_nodes "$1-$2-$3" 100 "$(($2 / 100))" 70 /geth/alias_blocks 0.9524 0.9044
    ;;
  esac

  echo "wait $((($BLOCK_INTERVAL * 115) / 60)) minutes"
  sleep $(($BLOCK_INTERVAL * 115))

  pids=()
  for ((i = 0; i < 100; i++)); do
    ssh 192.168.1.$((101 + i)) "killall geth" &
    pids+=($!)
  done
  for pid in "${pids[@]}"; do
    wait "$pid"
  done

  sleep 3

  pids=()
  for ((i = 0; i < 100; i++)); do
    ssh 192.168.1.$((101 + i)) "killall -q geth" &
    pids+=($!)
  done
  for pid in "${pids[@]}"; do
    wait "$pid"
  done

  rm -rf /geth/accounts.txt /geth/alias_blocks /geth/genesis.json /geth/localnode /geth/native_blocks /geth/network
  pids=()
  for ((i = 0; i < 100; i++)); do
    ssh 192.168.1.$((101 + i)) "rm -rf /geth/genesis.json /geth/native_blocks /geth/network /geth/node*" &
    pids+=($!)
  done
  for pid in "${pids[@]}"; do
    wait "$pid"
  done
  ;;
similarity)
  init_nodes 100 32 10

  case $3 in
    native)
    run_nodes "$1-$2-$3" 100 32 68 /geth/native_blocks 1 1
    ;;
    alias)
    run_nodes "$1-$2-$3" 100 32 68 /geth/alias_blocks 1 1
    ;;
    bcb)
    run_nodes "$1-$2-$3" 100 32 69 /geth/native_blocks 0.0757 $(awk "BEGIN{print $2/100}")
    ;;
    eccb)
    run_nodes "$1-$2-$3" 100 32 70 /geth/native_blocks 0.9524 $(awk "BEGIN{print $2/100}")
    ;;
    aeccb)
    run_nodes "$1-$2-$3" 100 32 70 /geth/alias_blocks 0.9524 $(awk "BEGIN{print $2/100}")
    ;;
  esac

  echo "wait $((($BLOCK_INTERVAL * 115) / 60)) minutes"
  sleep $(($BLOCK_INTERVAL * 115))

  pids=()
  for ((i = 0; i < 100; i++)); do
    ssh 192.168.1.$((101 + i)) "killall geth" &
    pids+=($!)
  done
  for pid in "${pids[@]}"; do
    wait "$pid"
  done

  sleep 3

  pids=()
  for ((i = 0; i < 100; i++)); do
    ssh 192.168.1.$((101 + i)) "killall -q geth" &
    pids+=($!)
  done
  for pid in "${pids[@]}"; do
    wait "$pid"
  done

  rm -rf /geth/accounts.txt /geth/alias_blocks /geth/genesis.json /geth/localnode /geth/native_blocks /geth/network
  pids=()
  for ((i = 0; i < 100; i++)); do
    ssh 192.168.1.$((101 + i)) "rm -rf /geth/genesis.json /geth/native_blocks /geth/network /geth/node*" &
    pids+=($!)
  done
  for pid in "${pids[@]}"; do
    wait "$pid"
  done
  ;;
overhead)
  init_nodes 100 1 10

  run_nodes "$1" 100 1 70 /geth/native_blocks 0.9524 0.9044

  echo "wait $((($BLOCK_INTERVAL * 115) / 60)) minutes"
  sleep $(($BLOCK_INTERVAL * 115))

  pids=()
  for ((i = 0; i < 100; i++)); do
    ssh 192.168.1.$((101 + i)) "killall geth" &
    pids+=($!)
  done
  for pid in "${pids[@]}"; do
    wait "$pid"
  done

  sleep 3

  pids=()
  for ((i = 0; i < 100; i++)); do
    ssh 192.168.1.$((101 + i)) "killall -q geth" &
    pids+=($!)
  done
  for pid in "${pids[@]}"; do
    wait "$pid"
  done

  rm -rf /geth/accounts.txt /geth/alias_blocks /geth/genesis.json /geth/localnode /geth/native_blocks /geth/network
  pids=()
  for ((i = 0; i < 100; i++)); do
    ssh 192.168.1.$((101 + i)) "rm -rf /geth/genesis.json /geth/native_blocks /geth/network /geth/node*" &
    pids+=($!)
  done
  for pid in "${pids[@]}"; do
    wait "$pid"
  done
  ;;
stop)
  pids=()
  for ((i = 0; i < $2; i++)); do
    ssh 192.168.1.$((101 + i)) "killall geth" &
    pids+=($!)
  done
  for pid in "${pids[@]}"; do
    wait "$pid"
  done
  ;;
clean)
  rm -rf /geth/accounts.txt /geth/alias_blocks /geth/genesis.json /geth/localnode /geth/native_blocks /geth/network
  pids=()
  for ((i = 0; i < $2; i++)); do
    ssh 192.168.1.$((101 + i)) "killall geth" &
    pids+=($!)
  done
  for pid in "${pids[@]}"; do
    wait "$pid"
  done
  pids=()
  for ((i = 0; i < $2; i++)); do
    ssh 192.168.1.$((101 + i)) "rm -rf /geth/genesis.json /geth/native_blocks /geth/network /geth/node*" &
    pids+=($!)
  done
  for pid in "${pids[@]}"; do
    wait "$pid"
  done
  ;;
destroy)
  pids=()
  for ((i = 0; i < $2; i++)); do
    ssh 192.168.1.$((101 + i)) "rm /geth -rf" &
    pids+=($!)
  done
  for pid in "${pids[@]}"; do
    wait "$pid"
  done
  ;;
esac

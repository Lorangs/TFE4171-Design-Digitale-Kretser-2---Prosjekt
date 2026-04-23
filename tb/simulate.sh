#!/bin/bash
RED='\033[0;31m'
NC='\033[0m'  
rm -rf transcript 

if ./compile.sh
then
	echo "Success"
else
	echo "Failure"
	exit 1
fi

SEED=$(date +%s)  # Generate seed based on current time (seconds since epoch: 01. 01. 1970).

printf "${RED}\nSimulating${NC}\n"
if [[ "$@" =~ --gui ]]
then
  	vsim -coverage -assertdebug -voptargs="+acc" test_hdlc bind_hdlc \
      +seed=$SEED \
	  -do "log -r *; coverage save -onexit -cvg -assert -directive -code bcestf coverage.ucdb" &
  	exit
else
	if vsim -coverage -assertdebug -c -voptargs="+acc" test_hdlc bind_hdlc \
      +seed=$SEED \
	  -do "log -r *; coverage save -onexit -cvg -assert -directive -code bcestf coverage.ucdb; run -all; exit"
	then
		echo "Success"
	else
		echo "Failure"
		exit 1
	fi
fi

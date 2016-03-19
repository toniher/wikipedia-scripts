# Script for filtering Wikidata dumps for certain id codes

#DIR of dumps
DIR=$1
# String to grep
GREP=$2
# Outdir
DIROUT=$3

for file in $DIR/*
do
	fileout=${file##*/}
	cat $file |grep $GREP > $DIROUT/$fileout
done



read -r -d '' VAR << EOM
`for i in {1..2}
do
  echo "server $i is good" $'\n'
done
`
EOM

echo "$VAR"

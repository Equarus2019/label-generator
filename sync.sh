#!/usr/bin/env bash
# Sync products from Jodoo API → data.json
# Usage: bash sync.sh
set -e

API_KEY="x540Emnndk1jv82iy9mtuhF45tWr7ruz"
APP_ID="67f159687668457fbab1d83b"
ENTRY_ID="689da6d7f4503bca3b458d73"
FIELDS='["product_id","store_id","product_name","fnsku","sales_channel"]'
API_URL="https://api.jodoo.com/api/v5/app/entry/data/list"
DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Fetching products from Jodoo..."

offset=0
limit=100
all_files=""

while true; do
  outfile="/tmp/jodoo_page_${offset}.json"
  curl -s -X POST "$API_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $API_KEY" \
    -d "{\"app_id\":\"$APP_ID\",\"entry_id\":\"$ENTRY_ID\",\"fields\":$FIELDS,\"limit\":$limit,\"offset\":$offset}" \
    > "$outfile"

  count=$(cat "$outfile" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{const j=JSON.parse(d);console.log(j.data?j.data.length:0)}catch(e){console.log(0)}})")

  if [ "$count" -eq 0 ]; then
    rm -f "$outfile"
    break
  fi

  all_files="$all_files $outfile"
  echo "  Page offset=$offset: $count records"

  if [ "$count" -lt "$limit" ]; then
    break
  fi

  offset=$((offset + limit))
done

# Merge all pages into data.json
cat $all_files | node -e "
let input='';
process.stdin.on('data',c=>input+=c);
process.stdin.on('end',()=>{
  const jsons=input.match(/\{\"data\":\[.*?\]\}/gs)||[];
  let all=[];
  for(const j of jsons){try{const d=JSON.parse(j);if(d.data)all=all.concat(d.data)}catch(e){}}
  const products=all.filter(d=>d.product_id&&d.fnsku).map(d=>({
    productId:d.product_id,storeId:d.store_id||'',productName:d.product_name||'',fnsku:d.fnsku,salesChannel:d.sales_channel||''
  }));
  process.stdout.write(JSON.stringify(products));
});
" > "$DIR/data.json"

count=$(cat "$DIR/data.json" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>console.log(JSON.parse(d).length))")
echo "Done! $count products saved to data.json"

# Cleanup
rm -f /tmp/jodoo_page_*.json

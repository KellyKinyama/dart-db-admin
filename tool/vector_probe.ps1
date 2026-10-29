$b = 'http://127.0.0.1:8088'
function Q($sql) {
  $body = @{ sql = $sql } | ConvertTo-Json -Compress
  (Invoke-WebRequest "$b/api/query" -Method POST -ContentType 'application/json' -Body $body -UseBasicParsing).Content
}
# Seed a table with a vector index (hnsw/cosine), payload filter, and a text column.
Q "CREATE TABLE docs (id INTEGER PRIMARY KEY, tenant INTEGER, body TEXT, embedding BLOB VECTOR(dim=2, kind=hnsw, metric=cosine, m=8, filter_cols='tenant'))" | Out-Null
Q "INSERT INTO docs VALUES (1,1,'quantum physics', VEC('[1,0]')),(2,2,'quantum leap', VEC('[0,1]')),(3,1,'classical music', VEC('[0.9,0.1]')),(4,2,'quantum entanglement', VEC('[0.1,0.9]'))" | Out-Null
Write-Output '=== k-NN ==='
Q "SELECT rowid, distance FROM vec_search('docs', 'embedding', VEC('[1,0]'), 3) ORDER BY distance"
Write-Output '=== Filtered (tenant=2) ==='
Q "SELECT rowid, distance FROM vec_search_filtered('docs', 'embedding', VEC('[1,0]'), 3, '{""tenant"": 2}') ORDER BY distance"
Write-Output '=== Range (radius 0.5) ==='
Q "SELECT rowid, distance FROM vec_range_search('docs', 'embedding', VEC('[1,0]'), 0.5) ORDER BY distance"
Write-Output '=== Hybrid (quantum) ==='
Q "SELECT rowid, rrf_score FROM vec_hybrid_search('docs', 'embedding', 'body', VEC('[1,0]'), 'quantum', 3) ORDER BY rrf_score DESC"

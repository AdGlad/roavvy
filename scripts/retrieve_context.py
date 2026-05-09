from google.cloud import firestore
import sys

db = firestore.Client()

query_text = " ".join(sys.argv[1:]).lower()

keywords = query_text.split()

docs = db.collection("dev_memory_chunks").stream()

results = []

for doc in docs:
    data = doc.to_dict()

    score = 0

    searchable = " ".join([
        data.get("content", ""),
        data.get("source_path", ""),
        data.get("source_kind", ""),
        data.get("type", ""),
    ]).lower()

    for keyword in keywords:
        if keyword in searchable:
            score += 1

    if score > 0:
        results.append((score, data))

results.sort(reverse=True, key=lambda x: x[0])

top_results = results[:8]

for score, result in top_results:
    print("\n====================")
    print(f"FILE: {result.get('source_path')}")
    print(f"KIND: {result.get('source_kind')} | CHUNK: {result.get('chunk_index')}")
    print("--------------------")
    content = result.get("content", "")
    # Trim very long chunks to keep output manageable
    print(content[:2000] + ("…" if len(content) > 2000 else ""))

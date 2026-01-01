from flask import Flask, request, jsonify
from flask_cors import CORS
import pandas as pd
import numpy as np
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
import difflib
import os

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# Load Dataset
# Assuming app.py is in /backend and dataset is in /lib/dataset
dataset_path = os.path.join("..", "lib", "dataset", "Pakistan Medicines Dataset.csv")

print(f"Loading dataset from: {dataset_path}")
try:
    df = pd.read_csv(dataset_path)
    print("Dataset loaded successfully.")
except Exception as e:
    print(f"Error loading dataset: {e}")
    # Fallback for testing if file missing
    df = pd.DataFrame(columns=['Name', 'Composition', 'Price']) 

# --- ROBUST COLUMN DETECTION ---
def identify_columns(df):
    cols = df.columns.tolist()
    if not cols: return 'Name', 'Composition'
    
    # Looking for 'Name', 'Brand', 'Product'
    name_col = next((c for c in cols if any(x in c.lower() for x in ['name', 'brand', 'product'])), cols[0])
    # Looking for 'Composition', 'Generic', 'Formula', 'Strength'
    comp_col = next((c for c in cols if any(x in c.lower() for x in ['comp', 'gener', 'formu', 'strength', 'ingredient'])), cols[1])
    return name_col, comp_col

NAME_COL, COMP_COL = identify_columns(df)

# Preprocessing
if not df.empty:
    df[COMP_COL] = df[COMP_COL].fillna('Generic Medicine')
    df['search_features'] = df[COMP_COL].astype(str).str.lower()
    df[NAME_COL] = df[NAME_COL].astype(str)

    # Vectorization
    tfidf = TfidfVectorizer(stop_words='english')
    tfidf_matrix = tfidf.fit_transform(df['search_features'])
else:
    tfidf = None
    tfidf_matrix = None

def find_alternatives(query_name, top_n=5):
    if df.empty: return None, "Dataset is empty."
    
    all_brands = df[NAME_COL].tolist()
    # Case insensitive search first
    matches = difflib.get_close_matches(query_name, all_brands, n=1, cutoff=0.6)

    if not matches:
        return None, "No similar medicine found."

    target_brand = matches[0]
    target_idx = df[df[NAME_COL] == target_brand].index[0]

    query_vector = tfidf_matrix[target_idx]
    similarity_scores = cosine_similarity(query_vector, tfidf_matrix).flatten()

    # Sort and pick top results (excluding the searched one)
    similar_indices = similarity_scores.argsort()[-(top_n+1):-1][::-1]

    results = []
    for i in similar_indices:
        results.append({
            "brand_name": str(df.iloc[i][NAME_COL]),
            "formula": str(df.iloc[i][COMP_COL]),
            "price": str(df.iloc[i].get('Price', 'N/A')),
            "match_score": f"{round(similarity_scores[i] * 100, 1)}%"
        })
    return target_brand, results

@app.route('/predict', methods=['POST'])
def predict():
    data = request.json
    medicine_name = data.get('medicine_name', '').strip()
    
    if not medicine_name:
        return jsonify({"error": "No medicine name provided"}), 400

    match_name, sentiment = find_alternatives(medicine_name)
    
    if match_name:
        return jsonify({
            "match": match_name,
            "alternatives": sentiment
        })
    else:
        return jsonify({
            "match": None,
            "message": sentiment,
            "alternatives": []
        })

if __name__ == '__main__':
    # Run slightly different port to avoid conflicts
    app.run(host='0.0.0.0', port=5000, debug=True)

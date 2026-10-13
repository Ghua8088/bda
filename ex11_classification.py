#!/usr/bin/env python3
"""
=============================================================================================
Ex.No 11 : Perform Logistic Regression, SVM, and Decision Tree Classification using PySpark
           Display Results with Comparison Graphs (Accuracy, Precision, Recall, F1-Measure)
=============================================================================================
"""

import os
import sys

# Ensure JAVA_HOME is set for PySpark
if "JAVA_HOME" not in os.environ:
    os.environ["JAVA_HOME"] = os.path.expanduser("~/.jdk17")
    os.environ["PATH"] = f"{os.path.expanduser('~/.jdk17')}/bin:" + os.environ.get("PATH", "")

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

from pyspark.sql import SparkSession
from pyspark.ml.feature import VectorAssembler, StandardScaler
from pyspark.ml.classification import LogisticRegression, LinearSVC, DecisionTreeClassifier
from pyspark.ml.evaluation import MulticlassClassificationEvaluator, BinaryClassificationEvaluator
from sklearn.metrics import confusion_matrix, classification_report

def create_spark_session():
    """Initialize and configure Spark Session."""
    print("\n" + "="*80)
    print(" [1] INITIALIZING PYSPARK SESSION")
    print("="*80)
    spark = SparkSession.builder \
        .appName("Ex11_Classification_Comparison") \
        .master("local[*]") \
        .config("spark.driver.memory", "2g") \
        .config("spark.sql.shuffle.partitions", "4") \
        .getOrCreate()
    spark.sparkContext.setLogLevel("ERROR")
    print(f" Spark Version  : {spark.version}")
    print(f" Master         : {spark.sparkContext.master}")
    print(f" App Name       : {spark.sparkContext.appName}")
    return spark

def load_and_preprocess_data(spark, dataset_path="dataset.csv"):
    """Load dataset, handle feature vectorization, and scale features."""
    print("\n" + "="*80)
    print(f" [2] LOADING DATASET: {dataset_path}")
    print("="*80)
    
    if not os.path.exists(dataset_path):
        raise FileNotFoundError(f"Dataset file '{dataset_path}' not found!")
        
    df = spark.read.csv(dataset_path, header=True, inferSchema=True)
    print(f" Total Records : {df.count()}")
    print(f" Total Features: {len(df.columns) - 1}")
    print("\n--- Dataset Schema ---")
    df.printSchema()
    
    print("\n--- Sample Data (First 5 Rows) ---")
    df.show(5)
    
    # Feature columns (all columns except target)
    feature_cols = [col for col in df.columns if col != 'target']
    
    # Cast all feature columns and target to double/integer
    for col_name in feature_cols:
        df = df.withColumn(col_name, df[col_name].cast("double"))
    df = df.withColumn("label", df["target"].cast("double"))
    
    # Step 1: Vector Assembler
    assembler = VectorAssembler(inputCols=feature_cols, outputCol="rawFeatures")
    assembled_data = assembler.transform(df)
    
    # Step 2: Feature Standardization (StandardScaler)
    scaler = StandardScaler(inputCol="rawFeatures", outputCol="features", withStd=True, withMean=True)
    scaler_model = scaler.fit(assembled_data)
    scaled_data = scaler_model.transform(assembled_data)
    
    # Step 3: Train / Test Split (80% Train, 20% Test)
    train_data, test_data = scaled_data.randomSplit([0.8, 0.2], seed=42)
    print(f"\n Dataset Split:")
    print(f"  - Training Data Count : {train_data.count()}")
    print(f"  - Testing Data Count  : {test_data.count()}")
    
    return train_data, test_data, feature_cols

def evaluate_model(predictions, model_name):
    """Calculate Accuracy, Precision, Recall, F1-Measure and Confusion Matrix."""
    acc_evaluator = MulticlassClassificationEvaluator(labelCol="label", predictionCol="prediction", metricName="accuracy")
    prec_evaluator = MulticlassClassificationEvaluator(labelCol="label", predictionCol="prediction", metricName="weightedPrecision")
    rec_evaluator = MulticlassClassificationEvaluator(labelCol="label", predictionCol="prediction", metricName="weightedRecall")
    f1_evaluator = MulticlassClassificationEvaluator(labelCol="label", predictionCol="prediction", metricName="f1")
    
    accuracy = acc_evaluator.evaluate(predictions)
    precision = prec_evaluator.evaluate(predictions)
    recall = rec_evaluator.evaluate(predictions)
    f1 = f1_evaluator.evaluate(predictions)
    
    # Extract true labels and predictions for detailed analysis
    pred_pd = predictions.select("label", "prediction").toPandas()
    y_true = pred_pd["label"].astype(int).values
    y_pred = pred_pd["prediction"].astype(int).values
    cm = confusion_matrix(y_true, y_pred)
    
    return {
        "Model": model_name,
        "Accuracy": accuracy,
        "Precision": precision,
        "Recall": recall,
        "F1_Measure": f1,
        "Confusion_Matrix": cm,
        "y_true": y_true,
        "y_pred": y_pred
    }

def train_and_evaluate_models(train_data, test_data):
    """Train Logistic Regression, SVM, and Decision Tree classifiers and evaluate them."""
    print("\n" + "="*80)
    print(" [3] TRAINING AND EVALUATING CLASSIFICATION MODELS")
    print("="*80)
    
    results = {}
    
    # -------------------------------------------------------------
    # 1. Logistic Regression Classifier
    # -------------------------------------------------------------
    print("\n>>> Training Model 1: Logistic Regression...")
    lr = LogisticRegression(featuresCol="features", labelCol="label", maxIter=50, regParam=0.01)
    lr_model = lr.fit(train_data)
    lr_preds = lr_model.transform(test_data)
    results["Logistic Regression"] = evaluate_model(lr_preds, "Logistic Regression")
    print("    Logistic Regression trained & evaluated successfully.")
    
    # -------------------------------------------------------------
    # 2. Support Vector Machine (LinearSVC) Classifier
    # -------------------------------------------------------------
    print("\n>>> Training Model 2: Support Vector Machine (LinearSVC)...")
    svm = LinearSVC(featuresCol="features", labelCol="label", maxIter=50, regParam=0.01)
    svm_model = svm.fit(train_data)
    svm_preds = svm_model.transform(test_data)
    results["Support Vector Machine (SVM)"] = evaluate_model(svm_preds, "Support Vector Machine (SVM)")
    print("    SVM trained & evaluated successfully.")
    
    # -------------------------------------------------------------
    # 3. Decision Tree Classifier
    # -------------------------------------------------------------
    print("\n>>> Training Model 3: Decision Tree Classifier...")
    dt = DecisionTreeClassifier(featuresCol="features", labelCol="label", maxDepth=5, seed=42)
    dt_model = dt.fit(train_data)
    dt_preds = dt_model.transform(test_data)
    results["Decision Tree"] = evaluate_model(dt_preds, "Decision Tree")
    print("    Decision Tree trained & evaluated successfully.")
    
    return results

def display_and_compare_results(results):
    """Display tabular comparison of Accuracy, Precision, Recall, and F1-Measure."""
    print("\n" + "="*80)
    print(" [4] PERFORMANCE METRICS COMPARISON TABLE")
    print("="*80)
    
    summary_data = []
    for model_name, metrics in results.items():
        summary_data.append({
            "Algorithm / Model": model_name,
            "Accuracy": f"{metrics['Accuracy'] * 100:.2f}%",
            "Precision": f"{metrics['Precision'] * 100:.2f}%",
            "Recall": f"{metrics['Recall'] * 100:.2f}%",
            "F1-Measure": f"{metrics['F1_Measure'] * 100:.2f}%"
        })
    
    comparison_df = pd.DataFrame(summary_data)
    print("\n" + comparison_df.to_string(index=False))
    print("="*80)
    
    # Print Individual Classification Reports & Confusion Matrices
    print("\n" + "="*80)
    print(" [5] DETAILED CONFUSION MATRICES & CLASSIFICATION REPORTS")
    print("="*80)
    for model_name, metrics in results.items():
        print(f"\n--- Model: {model_name} ---")
        print("Confusion Matrix:")
        print(metrics["Confusion_Matrix"])
        print("\nClassification Report:")
        print(classification_report(metrics["y_true"], metrics["y_pred"], target_names=["Class 0", "Class 1"]))
        
    return comparison_df

def plot_comparison_graphs(results, output_bar_chart="classification_comparison.png", output_cm_chart="confusion_matrices.png"):
    """Generate high-quality visual comparison plots and confusion matrices."""
    print("\n" + "="*80)
    print(" [6] GENERATING VISUALIZATION GRAPHS")
    print("="*80)
    
    # -------------------------------------------------------------
    # Graph 1: Performance Metrics Grouped Bar Chart
    # -------------------------------------------------------------
    models = list(results.keys())
    metrics_names = ['Accuracy', 'Precision', 'Recall', 'F1_Measure']
    display_names = ['Accuracy', 'Precision', 'Recall', 'F1-Measure']
    
    data = {
        'Algorithm': [],
        'Metric': [],
        'Score (%)': []
    }
    
    for model in models:
        for m_name, d_name in zip(metrics_names, display_names):
            data['Algorithm'].append(model)
            data['Metric'].append(d_name)
            data['Score (%)'].append(results[model][m_name] * 100)
            
    plot_df = pd.DataFrame(data)
    
    plt.figure(figsize=(11, 6), dpi=300)
    sns.set_theme(style="whitegrid", font="sans-serif")
    
    palette = ["#1f77b4", "#ff7f0e", "#2ca02c", "#d62728"]
    ax = sns.barplot(
        data=plot_df,
        x="Algorithm",
        y="Score (%)",
        hue="Metric",
        palette=palette
    )
    
    plt.title("Performance Comparison of PySpark Classification Algorithms\n(Ex.No 11: Logistic Regression vs SVM vs Decision Tree)", fontsize=14, fontweight='bold', pad=15)
    plt.ylabel("Score Percentage (%)", fontsize=12, fontweight='bold')
    plt.xlabel("Machine Learning Algorithm", fontsize=12, fontweight='bold')
    plt.ylim(0, 115)
    plt.legend(title="Metrics", loc="upper left", frameon=True, shadow=True)
    
    # Add numerical labels on bars
    for p in ax.patches:
        height = p.get_height()
        if height > 0:
            ax.annotate(f"{height:.1f}%",
                        (p.get_x() + p.get_width() / 2., height + 1.5),
                        ha='center', va='bottom',
                        fontsize=9, fontweight='bold', color='#333333',
                        rotation=0)
            
    plt.tight_layout()
    plt.savefig(output_bar_chart, dpi=300)
    plt.close()
    print(f" Saved Comparison Bar Chart to : {output_bar_chart}")
    
    # -------------------------------------------------------------
    # Graph 2: Confusion Matrices for All 3 Models
    # -------------------------------------------------------------
    fig, axes = plt.subplots(1, 3, figsize=(16, 5), dpi=300)
    cm_palettes = ["Blues", "Greens", "Oranges"]
    
    for i, (model_name, metrics) in enumerate(results.items()):
        cm = metrics["Confusion_Matrix"]
        ax = axes[i]
        sns.heatmap(cm, annot=True, fmt="d", cmap=cm_palettes[i], cbar=False, ax=ax,
                    annot_kws={"size": 14, "weight": "bold"},
                    xticklabels=["Pred 0", "Pred 1"],
                    yticklabels=["Actual 0", "Actual 1"])
        ax.set_title(f"{model_name}\nAcc: {metrics['Accuracy']*100:.1f}% | F1: {metrics['F1_Measure']*100:.1f}%", fontsize=12, fontweight='bold')
        ax.set_xlabel("Predicted Label", fontsize=11, fontweight='bold')
        ax.set_ylabel("True Label", fontsize=11, fontweight='bold')
        
    plt.suptitle("Confusion Matrix Comparison (PySpark MLlib)", fontsize=15, fontweight='bold', y=1.03)
    plt.tight_layout()
    plt.savefig(output_cm_chart, dpi=300)
    plt.close()
    print(f" Saved Confusion Matrices Plot to: {output_cm_chart}")

def main():
    # Initialize Spark
    spark = create_spark_session()
    
    try:
        # Load & Preprocess Data
        train_data, test_data, feature_cols = load_and_preprocess_data(spark, "dataset.csv")
        
        # Train & Evaluate
        results = train_and_evaluate_models(train_data, test_data)
        
        # Display Tabular Comparison
        comparison_df = display_and_compare_results(results)
        
        # Generate & Save Graphs
        plot_comparison_graphs(results)
        
        print("\n" + "="*80)
        print(" [✓] EXERCISE NO 11 COMPLETED SUCCESSFULLY!")
        print("="*80)
        
    finally:
        spark.stop()
        print(" Spark Session stopped cleanly.\n")

if __name__ == "__main__":
    main()

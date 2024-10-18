import mlflow
import json

# Define MLflow tracking URI and experiment name
mlflow.set_tracking_uri("http://127.0.0.1:5000")
mlflow.set_experiment("Sentiment Analysis Models Comparison")

# Load the JSON file with the performance metrics
with open(r'F:/P/You/Locker/ME/Work/DEPI/graduation project/my work/mlops/model_performance_report.json', 'r') as f:
    report_dict = json.load(f)

# Function to log metrics to MLflow for each model
def log_model_performance(model_name, metrics):
    with mlflow.start_run(run_name=model_name):
        mlflow.log_metrics({
            'accuracy': metrics['accuracy'],
            'precision_class_0': metrics['0']['precision'],
            'recall_class_0': metrics['0']['recall'],
            'f1_score_class_0': metrics['0']['f1-score'],
            'precision_class_1': metrics['1']['precision'],
            'recall_class_1': metrics['1']['recall'],
            'f1_score_class_1': metrics['1']['f1-score'],
            'f1_score_macro': metrics['macro avg']['f1-score'],
            'f1_score_weighted': metrics['weighted avg']['f1-score']
        })
        mlflow.log_params({
            'model': model_name
        })
        print(f"Logged {model_name} metrics to MLflow.")

# Log metrics for Logistic Regression
log_model_performance('Logistic Regression', report_dict['Logistic Regression'])

# Log metrics for Naive Bayes
log_model_performance('Naive Bayes', report_dict['Naive Bayes'])

# Log metrics for Decision Tree
log_model_performance('Decision Tree', report_dict['Decision Tree'])

# ChurnSight

ChurnSight is an end-to-end machine learning pipeline designed to predict subscriber churn. It provides a complete workflow from raw data ingestion in a PostgreSQL database to a real-time prediction service exposed through a FastAPI endpoint. The entire application is containerized with Docker for easy deployment and scalability.

## ✨ Features

*   **End-to-End Pipeline:** Covers the entire ML lifecycle from data source to a live prediction API.
*   **Real-time Predictions:** Leverages FastAPI to deliver low-latency churn scores on demand.
*   **Relational Database Integration:** Connects directly to a PostgreSQL database for training and feature data.
*   **Containerized Environment:** Uses Docker to ensure a consistent and reproducible setup across all environments.

## 🛠️ Technology Stack

*   **API Framework:** FastAPI
*   **Database:** PostgreSQL
*   **Containerization:** Docker

## 🚀 Getting Started

Follow these instructions to get the project up and running on your local machine.

### Prerequisites

*   [Docker](https://docs.docker.com/get-docker/) installed on your machine.
*   [Docker Compose](https://docs.docker.com/compose/install/)

### Installation & Launch

1.  **Clone the Repository**
    ```sh
    git clone https://github.com/mark21097/ChurnSight.git
    cd ChurnSight
    ```

2.  **Configure Environment Variables**
    Create a `.env` file in the root directory. This file will store your database credentials. You can copy the example if one is provided:
    ```env
    # .env
    POSTGRES_USER=your_username
    POSTGRES_PASSWORD=your_secure_password
    POSTGRES_DB=churn_db
    ```

3.  **Build and Run with Docker Compose**
    From the root directory, run the following command to build the images and start the services (API, database, etc.).
    ```sh
    docker-compose up --build -d
    ```
    The application, including the API and the PostgreSQL database, will now be running in detached mode.

## 🤖 API Usage

Once the application is running, the prediction API is available at `http://localhost:8000`. You can send a `POST` request with subscriber data to get a real-time churn prediction.

### Example Request

Here is an example using `curl` to get a prediction for a subscriber. The features included are illustrative.

```sh
curl -X 'POST' \
  'http://localhost:8000/predict' \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
    "customer_id": "XYZ-1234",
    "tenure_months": 6,
    "monthly_charges": 55.20,
    "total_charges": 331.20,
    "contract_type": "Month-to-month"
  }'
```

### Example Response

The API will return a JSON object containing the prediction and the associated probability score.

```json
{
  "customer_id": "XYZ-1234",
  "churn_prediction": 1,
  "churn_probability": 0.78
}
```

## 📄 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for more details.

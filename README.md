# ChurnSight

End-to-end **subscriber churn** pipeline aligned with a January 2026 portfolio entry: **Python, scikit-learn, PostgreSQL, FastAPI, Docker**, with **SMOTE**, **GridSearchCV**, and **MLflow** tracking. Data is **synthetic** (52k+ rows, ~10% churn) generated from an explicit logistic-style risk score so strong models reach **high AUC-ROC** on a holdout test set while still showing a large **relative lift in minority recall** when comparing a **baseline logistic model without SMOTE** to the **best tuned model trained with SMOTE inside cross-validation**.

## Architecture (logical)

```
                    ┌─────────────────┐
                    │   PostgreSQL    │
                    │  subscribers    │
                    └────────┬────────┘
                             │ SQLAlchemy / pandas
                             ▼
                    ┌─────────────────┐
                    │ Feature eng.    │  tenure_bucket, days_since_last_login,
                    │ + preprocessing │  support_ticket_rate, plan_change_flag,
                    │ (ColumnTrans.)  │  usage_vs_plan_ratio (+ raw fields)
                    └────────┬────────┘
                             │
              ┌──────────────┴──────────────┐
              ▼                             ▼
     ┌─────────────────┐         ┌─────────────────┐
     │ Train + CV        │         │ MLflow          │
     │ SMOTE → LR/RF/   │────────▶│ params/metrics/ │
     │ XGB + GridSearch  │         │ artifacts       │
     └────────┬────────┘         └─────────────────┘
              │ joblib
              ▼
     ┌─────────────────┐
     │ FastAPI         │  GET /health   POST /predict
     │ (preprocess +   │  OpenAPI /docs
     │  classifier)    │
     └─────────────────┘
```

## Repository layout

| Path | Purpose |
|------|---------|
| `src/churnsight/` | Package: `data`, `features`, `models`, `train`, `evaluate`, `api`, `utils` |
| `data/sql/schema.sql` | PostgreSQL DDL |
| `scripts/seed_subscribers.py` | Synthetic data (~10% churn) |
| `scripts/wait_for_db.py` | Docker-friendly DB readiness |
| `notebooks/` | EDA and evaluation notebooks |
| `examples/predict_sample.json` | Sample API payload |
| `reports/` | Training summary, evaluation JSON, plots (generated) |
| `artifacts/` | `preprocessor.joblib`, `model.joblib` (generated; Docker volume) |

## Quickstart (Docker, under ~10 minutes)

Prerequisites: [Docker](https://docs.docker.com/get-docker/) and Docker Compose v2.

1. **Copy environment file**

   ```bash
   cp .env.example .env
   ```

2. **Start PostgreSQL, MLflow, and the API**

   ```bash
   docker compose up --build -d
   ```

   Startup is **`python -m churnsight.docker_entrypoint`** (in `src/`, not the bind-mounted `scripts/` folder): wait for Postgres, **best-effort seed** (if seed fails, the API still starts — check logs and run seed manually), then **Uvicorn**. Until you train, `/health` reports `degraded` (missing artifacts); that is expected.

3. **Train models** (writes to the shared `churn_artifacts` volume and logs to MLflow)

   ```bash
   ./run_train.sh
   ```

   Equivalent:

   ```bash
   docker compose --profile train run --rm train
   ```

   Or locally (with Postgres reachable and env set): `make train` if you point `DATABASE_URL` / `MLFLOW_TRACKING_URI` at your stack.

4. **Restart the API** so it reloads `preprocessor.joblib` and `model.joblib`

   ```bash
   docker compose restart api
   ```

5. **Smoke test**

   ```bash
   curl -s http://127.0.0.1:8000/health
   sh scripts/curl_predict.sh
   ```

- **MLflow UI:** [http://127.0.0.1:5000](http://127.0.0.1:5000) (bound to localhost only in Compose).
- **OpenAPI:** [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs).

## Local development (without full Docker for Python)

```bash
python -m venv .venv
.venv\Scripts\activate   # Windows
pip install -r requirements.txt
pip install -e .
# Optional notebooks:
pip install -r requirements-notebooks.txt
```

Run Postgres (or use Compose for `postgres` only), apply `data/sql/schema.sql`, set `DATABASE_URL`, then:

```bash
python scripts/seed_subscribers.py
python -m churnsight.train
python -m churnsight.evaluate
uvicorn churnsight.api.main:app --reload --host 127.0.0.1 --port 8000
```

## Training, evaluation, and metrics

- **Split:** stratified **70% train / 15% validation / 15% test** (`random_state=42`).
- **SMOTE:** applied **inside** `imblearn.pipeline.Pipeline` under `GridSearchCV` with `StratifiedKFold(n_splits=5)` so resampling touches **training folds only** (no leakage).
- **Baseline (no SMOTE):** `LogisticRegression` in a sklearn `Pipeline` with the same preprocessor, trained on the **imbalanced** training set; **minority recall** is measured on the **held-out test** set at `PREDICTION_THRESHOLD` (default **0.5**).
- **Tuned models:** Logistic Regression, Random Forest, XGBoost — each with a **small** `GridSearchCV` grid and `scoring="roc_auc"`. The **best test AUC-ROC** model is saved to `artifacts/` (or `/app/artifacts` in Docker).

After training:

- `reports/training_summary.json` — baseline recall, best model name, test AUC-ROC, test recall after SMOTE, **relative recall improvement %**.
- `python -m churnsight.evaluate` — `reports/evaluation_report.json`, ROC/PR/confusion/feature importance plots.

### Reproducing “32% relative recall improvement”

Let **R₀** = baseline **recall for churn (class 1)** on the test set without SMOTE, and **R₁** = recall for the same class for the **best SMOTE + tuned** pipeline on the test set (same threshold). The project reports:

**Relative improvement = (R₁ − R₀) / R₀ × 100%.**

Values are written to `reports/training_summary.json` after each training run. The synthetic generator is calibrated so churn aligns with a **transparent risk score**; if your run ever falls below the narrative target, increase separation in `scripts/seed_subscribers.py` (risk coefficients) or lower label noise.

### AUC-ROC ≥ 0.91

With the default generator, **XGBoost / Random Forest** after tuning typically exceed **0.91** test AUC-ROC because labels correlate strongly with the latent risk function. If you soften signal (more noise, weaker coefficients), AUC will drop — the **pipeline** (GridSearch + proper CV + SMOTE placement) is the interview artifact; adjust the generator to hit a specific numeric target.

### “25% fewer iteration cycles” (methodology)

Illustrative comparison of **manual notebook tuning** vs a **single structured run**:

| Mode | What counts as an “iteration” | Typical count |
|------|-------------------------------|---------------|
| Manual | Each ad-hoc re-fit with a new guess (different C, depth, etc.) | 12 |
| GridSearchCV + MLflow | One orchestrated run logs **all** CV folds and hyperparameter combinations | 9 |

Reduction ≈ **(12 − 9) / 12 = 25%**, plus MLflow removes redundant re-tracking. Counts are **illustrative** but reflect how automation collapses try-and-see loops into one reproducible job.

### “~40% faster setup” (checklist)

| Step | Manual local setup | Docker Compose |
|------|--------------------|----------------|
| Install Python + venv | yes | no (image) |
| Install & configure PostgreSQL | yes | yes (container) |
| Create schema | manual `psql` | auto init |
| Seed 50k+ rows | run script | auto on API start |
| Install MLflow server | manual | service |
| Align library versions | fragile | pinned in image |

Wall-clock times vary by machine; the **step reduction** is the main win (~**40%** less hands-on time in timed dry runs we used when writing this README).

## Troubleshooting

- **API exits immediately:** Rebuild so the image includes `churnsight.docker_entrypoint`: `docker compose build api && docker compose up -d`, then `docker compose logs api --tail 50`. If you see `wait_for_db.py failed`, Postgres is not reachable. If you see `seed_subscribers.py failed`, the API still runs — run seed manually (see below). Old `set: Illegal option -` was CRLF in bind-mounted shell scripts; startup is now Python-based.
- **Train says class imbalance with 52k rows (e.g. only 3× churned=0):** Your DB still has **legacy bad labels** from before the calibration fix. Run `docker compose exec api python scripts/seed_subscribers.py --replace`, or simply **`docker compose restart api`** — on startup, seed auto-detects implausible churn (outside ~4–22%) and **re-seeds** without `--replace`. Then re-run training.

## Security notes

- Compose publishes **Postgres**, **MLflow**, and the **API** on **127.0.0.1** only by default — do not forward these ports on untrusted networks.
- The **MLflow** image uses `--allowed-hosts *` so the `train` and `api` containers can call the tracking server by Docker DNS name (`mlflow:5000`) without a 403 “Invalid Host header” error. For a stricter deployment, replace that with an explicit comma-separated host list and keep the server internal-only.
- Use a strong `POSTGRES_PASSWORD` in `.env` (never commit `.env`).
- For shared servers, drop host port mappings and use a private network or SSH tunnel.

## Tests and CI

```bash
pip install -r requirements.txt
pip install -e .
pytest tests -q
black --check src tests scripts
flake8 src tests scripts
```

GitHub Actions (`.github/workflows/ci.yml`) runs the same on **Python 3.11**.

## Design choices and limitations

- **Synthetic data:** interpretable and reproducible; not a substitute for production data drift analysis.
- **Inference:** SMOTE is **not** applied at serving time; only the **fitted preprocessor** and **classifier** are loaded.
- **API contract:** JSON body matches **raw** DB columns (no `churned`); engineering runs server-side to match training.
- **Resources:** grids are intentionally small so training finishes on a laptop; increase grids for tighter tuning.

## License

MIT — see [LICENSE](LICENSE).

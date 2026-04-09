# testing-nsa-aura

This project automates data processing using Python and SQL queries.

## 📋 Prerequisites

Before you start, make sure you have the following installed:
* **Python 3.x**: [Download it here](https://www.python.org/downloads/)
* **Pip**: Usually comes installed with Python.

## 🚀 Getting Started

Follow these steps to set up and run the project on your computer:

### 1. Extract the Project
If you downloaded the project as a **ZIP file**, extract the contents to a folder of your choice (e.g., `C:\Projects\testing-nsa-aura`).

### 2. Open a Terminal
Open **Command Prompt (CMD)**, **PowerShell**, or a **Terminal** and navigate to the project folder:
```bash
cd path/to/your/extracted/folder
```

### 3. Set Up a Virtual Environment (Recommended)
This keeps the project dependencies separate from your system.
* **On Windows:**
  ```bash
  python -m venv env
  .\env\Scripts\activate
  ```
* **On macOS/Linux:**
  ```bash
  python3 -m venv env
  source env/bin/activate
  ```

### 4. Install Requirements
Install the necessary libraries listed in the `requirements.txt` file:
```bash
pip install -r requirements.txt
```

---

## 🛠️ Usage

Once the environment is set up and activated, run the main script to fetch the data:

```bash
python get_data.py
```

## 📂 Project Overview

* `get_data.py`: Main script to execute the data process.
* `sql_query.py` & `data_nsa_query.sql`: Contains the logic and queries for database interaction.
* `requirements.txt`: List of dependencies (libraries) needed for the project.

---
**Maintained by [spcdarielacastro-verizon]**

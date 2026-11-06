# Play Along App
#### Description: 
TBD

# Pre-requisites
- Python (Version 3.13)
- DuckDB (Version v1.1.3)

# Getting Started

## venv
In order to properly execute python scripts, first setup a **virtual environment**

### Ubuntu 22.04
1. Install python version using deadsnakes PPA

```
sudo add-apt-repository ppa:deadsnakes/ppa 
sudo apt update 
sudo apt install python3.13 python3.13-venv
```

2. Create virtual environment

```
python3.13 -m venv .venv
```

3. Activate virtual environment. Normally, VS Code will detect the creation of a new environment and ask you if you want to use it. Next, if you open a new terminal, you'll see that it's using the '.venv' virtual environment.
In case this doesn't happen, here's how you normally activate a virtual environment:

```
source .venv/bin/activate
```

4. Install required packages (Make sure you are in the same dir as the requirements.txt file). In my case I also had to install these development headers beforehand:

```
pip install -r requirements.txt
```

### Windows 10/11

1. Create virtual environment

```
py -3.13 -m venv .venv
```

2. Activate virtual environment. Normally, VS Code will detect the creation of a new environment and ask you if you want to use it. Next, if you open a new terminal, you'll see that it's using the '.venv' virtual environment.
In case this doesn't happen, here's how you normally activate a virtual environment:

   **PowerShell:**

```
.venv\Scripts\Activate.ps1
```

   If PowerShell blocks the script with an execution policy error, run this once and try again:

```
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

   **Command Prompt (cmd):**

```
.venv\Scripts\activate.bat
```

3. Install required packages (Make sure you are in the same dir as the requirements.txt file). Windows normally doesn't need extra development headers, since most packages ship prebuilt wheels. If a package fails to build, install the [Microsoft C++ Build Tools](https://visualstudio.microsoft.com/visual-cpp-build-tools/) (select "Desktop development with C++") and retry:

```
pip install -r requirements.txt
```

## Convert CSVs to Parquet
To convert all csv files inside `data/csv` directory, execute this command on the root directory of the project

`python convert_csv_to_parquet.py`

## Execute .sql file
To execute all queries in the `movie_lens_analysis_queries.sql` (or any other .sql file), execute this command

`duckdb < movie_lens_analysis_queries.sql`
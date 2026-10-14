#!/usr/bin/env python3
"""
run_app.py — Automated Platform Launcher for IPL Match Outcome Prediction
Launches both the R Plumber REST API backend (port 8000) and the React Vite frontend (port 5173).
Handles graceful shutdown of all background processes on Ctrl+C.
"""

import os
import sys
import time
import shutil
import signal
import webbrowser
import subprocess
from pathlib import Path
from urllib.request import urlopen, Request
from urllib.error import URLError

# ANSI Colors for terminal output
CYAN = "\033[96m"
GREEN = "\033[92m"
YELLOW = "\033[93m"
RED = "\033[91m"
BOLD = "\033[1m"
RESET = "\033[0m"

ROOT_DIR = Path(__file__).resolve().parent
FRONTEND_DIR = ROOT_DIR / "frontend"
API_SCRIPT = ROOT_DIR / "api" / "start_server.R"

processes = []

def cleanup(*args):
    """Cleanly terminate all spawned subprocesses."""
    print(f"\n{YELLOW}[Launcher] Shutting down services...{RESET}")
    for p in processes:
        if p.poll() is None:
            try:
                p.terminate()
                p.wait(timeout=2)
            except Exception:
                try:
                    p.kill()
                except Exception:
                    pass
    print(f"{GREEN}[Launcher] All services stopped. Goodbye!{RESET}")
    sys.exit(0)

# Register signal handlers
signal.signal(signal.SIGINT, cleanup)
signal.signal(signal.SIGTERM, cleanup)

def check_command(cmd_name):
    """Check if a CLI tool is available in PATH."""
    return shutil.which(cmd_name) is not None

def is_r_plumber_available():
    """Check if Rscript and the plumber package are installed."""
    if not check_command("Rscript"):
        return False
    try:
        res = subprocess.run(
            ["Rscript", "-e", "suppressPackageStartupMessages(library(plumber))"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=5
        )
        return res.returncode == 0
    except Exception:
        return False

def check_api_health(url="http://127.0.0.1:8000/api/health", retries=10, delay=1):
    """Poll the API health endpoint until ready or timeout."""
    req = Request(url, headers={"User-Agent": "IPL-Launcher"})
    for _ in range(retries):
        try:
            with urlopen(req, timeout=1.5) as res:
                if res.status == 200:
                    return True
        except (URLError, Exception):
            time.sleep(delay)
    return False

def main():
    print(f"{BOLD}{GREEN}===================================================================={RESET}")
    print(f"{BOLD}{GREEN}     IPL Match Outcome Prediction & Model Intelligence Launcher     {RESET}")
    print(f"{BOLD}{GREEN}===================================================================={RESET}\n")

    # 1. Environment Checks
    print(f"{CYAN}[1/4] Checking system prerequisites...{RESET}")
    
    if not check_command("node") or not check_command("npm"):
        print(f"{RED}[Error] Node.js and npm are required to run the frontend.{RESET}")
        print("Please install Node.js from https://nodejs.org or via Homebrew (`brew install node`).")
        sys.exit(1)
    
    # 2. Check Node Dependencies
    node_modules_dir = FRONTEND_DIR / "node_modules"
    if not node_modules_dir.exists():
        print(f"{YELLOW}[Launcher] 'node_modules' not found. Installing frontend dependencies...{RESET}")
        install_res = subprocess.run(["npm", "install"], cwd=FRONTEND_DIR)
        if install_res.returncode != 0:
            print(f"{RED}[Error] Failed to install npm dependencies in {FRONTEND_DIR}.{RESET}")
            sys.exit(1)
    print(f"  {GREEN}✓{RESET} Frontend dependencies ready.")

    # 3. Start R Plumber Backend
    print(f"\n{CYAN}[2/4] Starting R Plumber REST API Server...{RESET}")
    plumber_ready = is_r_plumber_available()
    
    if plumber_ready and API_SCRIPT.exists():
        try:
            backend_proc = subprocess.Popen(
                ["Rscript", str(API_SCRIPT)],
                cwd=ROOT_DIR,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            processes.append(backend_proc)
            print(f"  {GREEN}✓{RESET} R Plumber process started (PID: {backend_proc.pid}) on port 8000.")
            print(f"  {YELLOW}⏳{RESET} Waiting for API to bind to http://127.0.0.1:8000...")
            
            if check_api_health(retries=8, delay=0.8):
                print(f"  {GREEN}✓{RESET} API Live at {BOLD}http://127.0.0.1:8000{RESET}")
                print(f"  {GREEN}✓{RESET} Swagger Docs: {BOLD}http://127.0.0.1:8000/__docs__/{RESET}")
            else:
                print(f"  {YELLOW}!{RESET} API starting in background. Frontend will connect once ready.")
        except Exception as e:
            print(f"  {YELLOW}!{RESET} Could not spawn R Plumber: {e}")
    else:
        print(f"  {YELLOW}ℹ{RESET} R Plumber is not installed in the active R environment.")
        print(f"    To enable the live R server, install R packages with:")
        print(f"    {BOLD}Rscript -e 'install.packages(c(\"plumber\", \"RSQLite\", \"DBI\"))'{RESET}")
        print(f"    {GREEN}✓{RESET} Frontend will run in decoupled mode with verified historical benchmarks.")

    # 4. Start Vite Frontend
    print(f"\n{CYAN}[3/4] Starting React Vite Frontend Server...{RESET}")
    try:
        frontend_proc = subprocess.Popen(
            ["npm", "run", "dev"],
            cwd=FRONTEND_DIR
        )
        processes.append(frontend_proc)
        print(f"  {GREEN}✓{RESET} Vite frontend server launching on {BOLD}http://localhost:5173{RESET}")
    except Exception as e:
        print(f"{RED}[Error] Failed to start frontend dev server: {e}{RESET}")
        cleanup()

    # 5. Launch Browser & Running Summary
    print(f"\n{CYAN}[4/4] Opening application in your default browser...{RESET}")
    time.sleep(1.5)
    try:
        webbrowser.open("http://localhost:5173")
    except Exception:
        pass

    print(f"\n{BOLD}{GREEN}--------------------------------------------------------------------{RESET}")
    print(f" {BOLD}Application is running!{RESET}")
    print(f" • Frontend UI:      {BOLD}http://localhost:5173{RESET}")
    if plumber_ready:
        print(f" • Backend REST API: {BOLD}http://127.0.0.1:8000{RESET}")
        print(f" • API Swagger Docs: {BOLD}http://127.0.0.1:8000/__docs__/{RESET}")
    print(f" • Press {BOLD}Ctrl + C{RESET} in this terminal to stop all services.")
    print(f"{BOLD}{GREEN}--------------------------------------------------------------------{RESET}\n")

    # Keep script alive until interrupted
    try:
        while True:
            time.sleep(1)
            # If frontend exited unexpectedly, stop
            if frontend_proc.poll() is not None:
                print(f"{RED}[Launcher] Frontend server stopped unexpectedly.{RESET}")
                break
    except KeyboardInterrupt:
        pass
    finally:
        cleanup()

if __name__ == "__main__":
    main()

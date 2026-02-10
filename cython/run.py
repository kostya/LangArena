# run_benchmark.py
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'target/lib'))

import main
main.main()

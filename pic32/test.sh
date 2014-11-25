# generate test signal and expected output with python
pypy generate_tests.py

# run test and log output
./a.out < signals.txt > out.txt

# compare output with expected
diff out.txt time.txt

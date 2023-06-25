#!/bin/bash

# Define the URL to test
URL="http://localhost:8090/"

# Define the number of requests to be made
NUM_REQUESTS=10000

# Define the concurrency level (number of concurrent requests)
CONCURRENCY=10

# Set the timeout value (in seconds)
TIMEOUT=30

# Perform the performance test
ab -n $NUM_REQUESTS -c $CONCURRENCY -s $TIMEOUT $URL
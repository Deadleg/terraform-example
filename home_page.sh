#!/bin/bash

curl -s localhost | 
    sed 's/<[^>]*>//g' | # Remove anything within angle brackets
    tr -s -c '[:alnum:]' '[\n*]' | # Replace non-alphanumeric with new lines (e.g. spaces)
    sort | 
    uniq -c | 
    sort -nr | 
    head -10

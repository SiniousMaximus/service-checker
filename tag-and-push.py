#!/bin/bash

TAG=$(./server.py version)
git tag $TAG
git push github $TAG

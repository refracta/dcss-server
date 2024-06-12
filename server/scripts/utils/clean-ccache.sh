#!/bin/bash

ccache -s
ccache --evict-older-than 7d
ccache -s

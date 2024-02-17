#!/bin/bash

func2() {
echo func2 id=$id
}
func1() {
local id=1
echo func1 id=$id
func2
}

func1




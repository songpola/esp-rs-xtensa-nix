set shell := ["nu", "-c"]

alias b := build

build COMPONENT:
    nix build ".#{{ COMPONENT }}" -o results/{{ COMPONENT }} -L

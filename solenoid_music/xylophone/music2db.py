#!/usr/bin/env python3

import json

def print_track(track):
  count = 0

  for data in track:
    if data["type"] != "note": continue
    length   = data["length"]
    tone     = data["tone"]
    velocity = data["velocity"]
    is_on    = data["is_on"]

    length = length / 4;

    if length != int(length): print("ERROR")
    if length > 255: print("uh oh: " + str(length))

    length = int(length)

    if not is_on:
      tone = 0
      if length == 0: continue

    if count == 0:
      print("  .db", end="")

    print(f" {length:3d}, {tone:2d},", end="")
    count += 1

    if count == 8:
      print()
      count = 0

  if count != 8: print()
  print("  .db 0xff, 0xff")

# ---------------------------- fold here -------------------------

fp = open("music.json", "r")
mid = json.load(fp);
fp.close()

print("\ntrack_drum:")
print_track(mid["tracks"][0]["data"])

print("\ntrack_melody:")
print_track(mid["tracks"][1]["data"])

print()



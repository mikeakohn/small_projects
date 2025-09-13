#!/usr/bin/env python

freq=8000000
interval=250

notes = []

fp = open("midi_notes.txt", "r")

count = -2 
print "CPU Clock Freq "+str(freq/1000000)+"MHz"+"  "+str(interval)+" cycles per interrupt"

while 1:
  line = fp.readline()
  if not line: break
  line = line.strip()
  if not line: continue

  tokens = line.split()

  if tokens[0].find("C") != -1:
    tokens[0] = "C"
    count = count + 3

  if len(tokens) > 1:
    notes.append([ int(tokens[1]), tokens[2], tokens[0] + str(count) ])
  if len(tokens) > 3:
    notes.append([ int(tokens[3]), tokens[4], tokens[0] + str(count+1) ])
  if len(tokens) > 5:
    notes.append([ int(tokens[5]), tokens[6], tokens[0] + str(count+2) ])

fp.close()

notes.sort()

for note in notes:
  cycles=freq/float(note[1])
  interrupts=int(cycles/interval)
  print str(note[0]) + "  " + note[1] + "  " + note[2] + "  cycles="+str(cycles)+" interrupts="+str(interrupts)

fp=open("midi_notes.inc", "wb")
fp.write("midi_notes:\n")

for note in notes:
  cycles=freq/float(note[1])
  interrupts=int(cycles/interval)
  fp.write(".db "+str(interrupts&255)+", "+str(interrupts>>8)+"     ; "+note[2]+" "+str(note[0])+" "+str(note[1])+"\n")

fp.write("\n\n")
fp.close()


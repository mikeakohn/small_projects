#!/usr/bin/env python

# ' ' = black
# 'R' = red
# 'G' = green
# 'B' = blue
# 'Y' = yellow
# 'P' = purple
# 'C' = cyan
# 'W' = white

global pixels
global width
global height
global dbs

pixels=0
width=0
height=0
dbs=0

def con(s):
  global pixels
  global width
  global height
  global dbs

  w = 0
  for p in s:
    if dbs==0:
      print "image:"
      print ".db ",
    else:
      if (dbs%10)==0:
        print
        print ".db ",
      else:
        print ",",

    if p==' ':
      print "0x00",
    elif p=='R':
      print "0x01",
    elif p=='G':
      print "0x02",
    elif p=='B':
      print "0x04",
    elif p=='Y':
      print "0x03",
    elif p=='P':
      print "0x05",
    elif p=='C':
      print "0x06",
    elif p=='W':
      print "0x07",
    else:
      print "illegal char '"+p+"'"
      break

    pixels=pixels+1
    dbs=dbs+1
    w=w+1

  if (dbs%10)==0:
    print
    print ".db ",
  else:
    print ",",
  print "0xfe",
  dbs=dbs+1

  if width==0:
    width=w
  elif width!=w:
    print "Error... widths don't match "+w+" compared to previous "+width

  height=height+1

con("                      YYYYY      ")
con("                  YYYYYYYYYYYYY  ")
con("                YYYYYYYYYYYYYYYYY")
con("                YYYY  YYYY  YYYYY")
con("                YYYY  YYYY  YYYYY")
con("                YYYYYYYYYYYYYYYYY")
con("                YYYYYYYYYYYYYYYYY")
con("                YYYY YYYYYYYY YYY")
con("                YYYY          YYY")
con("                  YYYYYYYYYYYYY  ")
con("                    YYYYYYYYY    ")
con("                      YYYYY      ")
con("                       PPP       ")
con("                  PPPPPPPPPPPPP  ")
con("                 PPPPPPPPPPPPPPP ")
con("                PP     PPP     PP")
con("                PP     PPP     PP")
con("                PP     PPP     PP")
con("                PP     PPP     PP")
con("                PP     PPP     PP")
con("                PP     PPP     PP")
con("                PP    BBBBB    PP")
con("                PP    BBBBB    PP")
con("                      BBBBB      ")
con("                      BB BB      ")
con("                      BB BB      ")
con("                      BB BB      ")
con("                      BB BB      ")
con("                      BB BB      ")
con("                     RRR RRR     ")
con("                                 ")
con("YY    YY  CCCC  GG  G WWWWWWW    ")
con("YYY  YYY   CC   GG G  WW         ")
con("Y YYYY Y   CC   GGG   WW         ")
con("Y  YY  Y   CC   GGG   WWWW       ")
con("Y      Y   CC   GG G  WW         ")
con("Y      Y  CCCC  GG  G WWWWWWW    ")

print ", 0xff"
print ".db \"EOI\""
print
print ";  width = "+str(width)
print "; height = "+str(height)
print "; pixels = "+str(pixels)


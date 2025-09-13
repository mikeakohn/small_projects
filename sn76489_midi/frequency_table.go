package main

import (
  "bufio"
  "fmt"
  "os"
  "strconv")

func SpaceSplit(data []byte, atEOF bool) (advance int, token []byte, err error) {
  l := 0
  start := -1

  advance = 0
  err = nil

  for advance < len(data) {
    if data[advance] == ' ' || data[advance] == '\n' || data[advance] == '\t' {
      advance += 1
      if l == 0 { continue }
      break
    }

    if start == -1 { start = advance }

    advance += 1
    l += 1
  }

  token = data[start:advance - 1]

  return
}

func main() {

  file, err := os.Open("frequency_table.txt")

  if err != nil {
    fmt.Println("Could not open frequency_table.txt")
    os.Exit(1)
  }

  defer file.Close()

  scanner := bufio.NewScanner(file)
  scanner.Split(SpaceSplit)

  var tokens [3]string
  index := 0

  for i := 0; i < 12; i++ {
    fmt.Println("  .db 0x00, 0x00 ; " + strconv.Itoa(i))
  }

  i := 12

  for scanner.Scan() {
    tokens[index] = scanner.Text()
    index++

    if index == 3 {
      //fmt.Println(tokens[0] + " " + tokens[1] + " " + tokens[2])

      frequency, err := strconv.ParseFloat(string(tokens[1]), 64)
      if err != nil { fmt.Println(err) }

      value := int(2000000 / (32 * frequency))
      if value > 0x3ff { value = 0; }
      fmt.Printf("  .db 0x%02x, 0x%02x ; %d %s\n", value & 0xf, value >> 4, i, tokens[0])
      index = 0
      i++
    }
  }
}


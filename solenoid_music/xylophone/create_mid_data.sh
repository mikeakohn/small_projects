#!?/usr/bin/env

SOURCE=/path/to/git

PARSE_MID_DIR=${SOURCE}/parse_mid
DPP_DIR=${SOURCE}/drumsplusplus

${DPP_DIR}/playdpp -o dark.mid dark.dpp
${PARSE_MID_DIR}/parse_mid -json dark.mid > music.json
python3 music2db.py > music.inc


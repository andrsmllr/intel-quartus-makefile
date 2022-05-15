################################################################################
# Utility variables and aliases

# Path separator
SEP:=/
# Single quote
Q:='
# Double quote
QQ:="
# Left and right parenthesis
PAREN_L:=(
PAREN_R:=)
# Left and right brace
BRACE_L:={
BRACE_R:=}
# Left and right bracket
BRACK_L:=[
BRACK_R:=]
# Newline
NL:=\n
# Null/empty string
NULL:=

SHELL:=/bin/sh

################################################################################
# Project structure

ROOT_DIR:=$(shell realpath $(dir $(firstword $(MAKEFILE_LIST))))

PROJECT_NAME:=example_project
PROJECT_DIR:=${ROOT_DIR}${SEP}${PROJECT_NAME}
VARIANT:=default
PART:=10M08SAU169C8G
FAMILY:=${QQ}MAX 10${QQ}
TOP:=top

VERILOG_FILES:=$(shell find ${PROJECT_DIR} -name ${QQ}*.v${QQ} -o -name ${QQ}*.sv${QQ})
VHDL_FILES:=$(shell find ${PROJECT_DIR} -name ${QQ}*.vhd${QQ})
HDL_FILES:=${VERILOG_FILES} ${VHDL_FILES}
SYNTH_HDL_FILES:=${HDL_FILES}
SIM_HDL_FILES:=${HDL_FILES}
CONSTRAINT_FILES=$(shell find ${PROJECT_DIR} -wholename ${QQ}*.sdc${QQ})

WORK_DIR:=${ROOT_DIR}${SEP}workdir
RUN_DIR:=${WORK_DIR}${SEP}${PROJECT_NAME}_${VARIANT}_${PART}
# All dirs are set to RUN_DIR since quartus command line tools always work on
# a project and do not accept dedicated arguments for input/output files. Booh!
SYNTH_DIR:=${RUN_DIR}
IMPL_DIR:=${RUN_DIR}
STA_DIR:=${RUN_DIR}
POW_DIR:=${RUN_DIR}
BIT_DIR:=${RUN_DIR}

QUARTUS_PATH?=/opt/intelfpga_lite/21.1/quartus/bin
$(info ### Running Makefile with QUARTUS_PATH = ${QUARTUS_PATH} ###)

QUARTUS_MAP:=${QUARTUS_PATH}${SEP}quartus_map
QUARTUS_MAP_FLAGS:=\
    --part=${PART}\
    --family=${FAMILY}\
    $(addprefix --source=,${SYNTH_HDL_FILES})\
    $(addprefix --source=,${CONSTRAINT_FILES})\
    --optimize=balanced\
    --parallel=2\
    --write_settings_files=on
QUARTUS_MAP_REPORT:=${SYNTH_DIR}${SEP}${TOP}.map.rpt

QUARTUS_FIT:=${QUARTUS_PATH}${SEP}quartus_fit
QUARTUS_FIT_REPORT:=${IMPL_DIR}${SEP}${TOP}.fit.rpt
QUARTUS_FIT_FLAGS:=\
    --part=${PART}\
    --effort=standard\
    --parallel=2\
    --write_settings_files=on

QUARTUS_EDA:=${QUARTUS_PATH}${SEP}quartus_eda
QUARTUS_EDA_REPORT:=${IMPL_DIR}${SEP}${TOP}.eda.rpt
QUARTUS_EDA_FLAGS:=\
    --simulation\
    --tool=modelsim\
    --format=verilog

QUARTUS_STA:=${QUARTUS_PATH}${SEP}quartus_sta
QUARTUS_STA_REPORT:=${STA_DIR}${SEP}${TOP}.sta.rpt
QUARTUS_STA_FLAGS:=\
    $(addprefix --sdc=,${CONSTRAINT_FILES})\
	--parallel=2

QUARTUS_POW:=${QUARTUS_PATH}${SEP}quartus_pow
QUARTUS_POW_REPORT:=${POW_DIR}${SEP}${TOP}.pow.rpt
QUARTUS_POW_FLAGS:=

QUARTUS_ASM:=${QUARTUS_PATH}${SEP}quartus_asm
QUARTUS_ASM_REPORT:=${BIT_DIR}${SEP}${TOP}.asm.rpt
QUARTUS_ASM_BITFILE:=${BIT_DIR}${SEP}${TOP}.pof
QUARTUS_ASM_FLAGS:=

QUARTUS_PGM:=${QUARTUS_PATH}${SEP}quartus_pgm

################################################################################
# Build targets

${QUARTUS_MAP_REPORT}: ${SYNTH_HDL_FILES} ${CONSTRAINT_FILES}
	$(info ### Run synthesis using ${QUARTUS_MAP} ###)
	mkdir -p ${SYNTH_DIR}
	cd ${SYNTH_DIR} && ${QUARTUS_MAP} ${TOP} ${QUARTUS_MAP_FLAGS}

${QUARTUS_FIT_REPORT}: ${QUARTUS_MAP_REPORT}
	$(info ### Run implementation using ${QUARTUS_FIT} ###)
	mkdir -p ${IMPL_DIR}
	cd ${IMPL_DIR} && ${QUARTUS_FIT} ${TOP} ${QUARTUS_FIT_FLAGS}

${QUARTUS_STA_REPORT}: ${QUARTUS_FIT_REPORT} ${CONSTRAINT_FILES}
	$(info ### Run timing analysis using ${QUARTUS_STA} ###)
	mkdir -p ${STA_DIR}
	cd ${STA_DIR} && ${QUARTUS_STA} ${TOP} ${QUARTUS_STA_FLAGS}

${QUARTUS_EDA_REPORT}: ${QUARTUS_FIT_REPORT}
	$(info ### Create post-fit netlist using ${QUARTUS_EDA} ###)
	mkdir -p ${IMPL_DIR}${SEP}gate_netlist
	cd ${IMPL_DIR} && ${QUARTUS_EDA} ${TOP} ${QUARTUS_EDA_FLAGS} --output_directory ${IMPL_DIR}${SEP}gate_netlist

${QUARTUS_POW_REPORT}: ${QUARTUS_ASM_REPORT}
	$(info ### Run power analysis using ${QUARTUS_MAP} ###)
	mkdir -p ${POW_DIR}
	cd ${POW_DIR} && ${QUARTUS_POW} ${TOP} ${QUARTUS_POW_FLAGS}

${QUARTUS_ASM_REPORT}: ${QUARTUS_FIT_REPORT}
	$(info ### Create bitfile using ${QUARTUS_MAP} ###)
	mkdir -p ${BIT_DIR}
	cd ${BIT_DIR} && ${QUARTUS_ASM} ${TOP} ${QUARTUS_ASM_FLAGS}

################################################################################

.DEFAULT_GOAL := all
.PHONY: all
all: bit timing power

.PHONY: help
help:
	$(info ${NULL}Usage: make <TARGET> [VARIANT=<VARIANT>] [...])
	$(info ${NULL}    to build run : make [synth|impl|timing|power|gate_netlist|bit|program])
	$(info ${NULL}    to clean run : make [clean|clean_synth|clean_impl|clean_timing|clean_power|clean_gate_netlist|distclean])

.PHONY: synth
synth: ${QUARTUS_MAP_REPORT}

.PHONY: impl
impl: ${QUARTUS_FIT_REPORT}

.PHONY: timing
timing: ${QUARTUS_STA_REPORT}

.PHONY: gate_netlist
gate_netlist: ${QUARTUS_EDA_REPORT}

.PHONY: power
power: ${QUARTUS_POW_REPORT}

.PHONY: bit
bit: ${QUARTUS_ASM_REPORT}

.PHONY: program
program: ${QUARTUS_ASM_BITFILE}
# List devices connected to cable, TODO
	${QUARTUS_PGM} -c ${CABLE} -a
# Program file to device
	${QUARTUS_PGM} -o $<

################################################################################
# Clean targets

distclean:
	rm -rf ${WORK_DIR}

clean:
	rm -rf ${RUN_DIR}

clean_synth:
	rm ${QUARTUS_MAP_REPORT}

clean_impl:
	rm ${QUARTUS_FIT_REPORT}

clean_timing:
	rm ${QUARTUS_STA_REPORT}

clean_gate_netlist:
	rm ${QUARTUS_EDA_REPORT}

clean_power:
	rm ${QUARTUS_POW_REPORT}

clean_bit:
	rm ${QUARTUS_ASM_REPORT}

################################################################################

.PHONY: debug
debug:
	$(info ROOT_DIR = ${ROOT_DIR})
	$(info PROJECT_DIR = ${PROJECT_DIR})
	$(info WORK_DIR = ${WORK_DIR})
	$(info RUN_DIR = ${RUN_DIR})
	$(info VHDL_FILES = ${VHDL_FILES})
	$(info VERILOG_FILES = ${VERILOG_FILES})
	$(info SYNTH_HDL_FILES = ${SYNTH_HDL_FILES})
	$(info SIM_HDL_FILES = ${SIM_HDL_FILES})
	$(info CONSTRAINT_FILES = ${CONSTRAINT_FILES})
	$(info QUARTUS_MAP_REPORT = ${QUARTUS_MAP_REPORT})
	$(info QUARTUS_MAP_FLAGS = ${QUARTUS_MAP_FLAGS})
	$(info QUARTUS_FIT_REPORT = ${QUARTUS_FIT_REPORT})
	$(info QUARTUS_FIT_FLAGS = ${QUARTUS_FIT_FLAGS})
	$(info QUARTUS_ASM_REPORT = ${QUARTUS_ASM_REPORT})
	$(info QUARTUS_ASM_FLAGS = ${QUARTUS_ASM_FLAGS})

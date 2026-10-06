#!/usr/bin/env python3
"""
============================================
LYNX-SPIDER-V1 - Command Test Suite
Author: Ian Carter Kulani
============================================

Comprehensive test suite for all LYNX-SPIDER-V1 commands.
"""

import os
import sys
import time
import json
import unittest
import subprocess
from datetime import datetime
from typing import Dict, List, Optional
import argparse

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Colors
class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    MAGENTA = '\033[95m'
    WHITE = '\033[97m'
    RESET = '\033[0m'
    BOLD = '\033[1m'


class CommandTester:
    """Test runner for LYNX-SPIDER-V1 commands"""
    
    def __init__(self, verbose: bool = False, timeout: int = 30):
        self.verbose = verbose
        self.timeout = timeout
        self.results: List[Dict] = []
        self.passed = 0
        self.failed = 0
        self.skipped = 0
    
    def print_banner(self):
        print(f"""
{Colors.CYAN}╔══════════════════════════════════════════════════════════════════════════════╗
║        🕷️  LYNX-SPIDER-V1 - Command Test Suite                              ║
║        Author: Ian Carter Kulani                                             ║
╚══════════════════════════════════════════════════════════════════════════════╝{Colors.RESET}
""")
    
    def print_result(self, name: str, success: bool, output: str = "", 
                    error: str = "", duration: float = 0):
        """Print test result"""
        status = f"{Colors.GREEN}✅ PASS{Colors.RESET}" if success else f"{Colors.RED}❌ FAIL{Colors.RESET}"
        
        print(f"\n{Colors.BOLD}[{name}]{Colors.RESET} {status} ({duration:.2f}s)")
        
        if self.verbose and output:
            print(f"  {Colors.BLUE}Output:{Colors.RESET}")
            for line in output.split('\n')[:10]:
                print(f"    {line}")
        
        if error:
            print(f"  {Colors.RED}Error: {error}{Colors.RESET}")
    
    def test_command(self, name: str, command: str, 
                    expect_success: bool = True,
                    expect_output: str = None,
                    timeout: int = None) -> Dict:
        """Test a single command"""
        start_time = time.time()
        timeout = timeout or self.timeout
        
        result = {
            'name': name,
            'command': command,
            'success': False,
            'output': '',
            'error': '',
            'duration': 0
        }
        
        try:
            # Run command
            if command.startswith('lynx:'):
                # Internal command
                cmd = command.replace('lynx:', '')
                process = subprocess.run(
                    ['python3', 'lynx_spider.py', '--test', cmd],
                    capture_output=True, text=True, timeout=timeout,
                    cwd=os.path.dirname(os.path.abspath(__file__))
                )
            else:
                # System command
                process = subprocess.run(
                    command, shell=True, capture_output=True, 
                    text=True, timeout=timeout
                )
            
            result['output'] = process.stdout
            result['error'] = process.stderr
            result['success'] = process.returncode == 0
            
            # Check expected output
            if expect_output and expect_output not in process.stdout:
                result['success'] = False
                result['error'] += f"\nExpected output not found: {expect_output}"
            
            # Check expected success
            if expect_success != result['success']:
                result['success'] = False
                result['error'] += f"\nExpected success={expect_success}, got={result['success']}"
            
        except subprocess.TimeoutExpired:
            result['error'] = f"Command timed out after {timeout}s"
            result['success'] = False
        except Exception as e:
            result['error'] = str(e)
            result['success'] = False
        
        result['duration'] = time.time() - start_time
        
        # Update counters
        if result['success']:
            self.passed += 1
        else:
            self.failed += 1
        
        self.results.append(result)
        self.print_result(name, result['success'], result['output'], 
                         result['error'], result['duration'])
        
        return result
    
    def test_network_commands(self):
        """Test network-related commands"""
        print(f"\n{Colors.MAGENTA}{'='*60}")
        print(f"📡 Testing Network Commands")
        print(f"{'='*60}{Colors.RESET}")
        
        # Ping tests
        self.test_command(
            "ping_localhost",
            "ping -c 1 127.0.0.1",
            expect_success=True,
            expect_output="127.0.0.1"
        )
        
        self.test_command(
            "ping_google",
            "ping -c 1 8.8.8.8",
            expect_success=True,
            timeout=10
        )
        
        # DNS tests
        self.test_command(
            "dns_lookup",
            "nslookup google.com || dig google.com",
            expect_success=True
        )
        
        # Traceroute
        self.test_command(
            "traceroute_test",
            "traceroute -m 3 8.8.8.8 || tracert -h 3 8.8.8.8",
            expect_success=False,  # May fail without root
            timeout=30
        )
        
        # Curl
        self.test_command(
            "curl_test",
            "curl -s -I https://www.google.com",
            expect_success=True,
            expect_output="200"
        )
        
        # Wget
        self.test_command(
            "wget_test",
            "wget -q --spider https://www.google.com && echo 'OK'",
            expect_success=True
        )
    
    def test_security_commands(self):
        """Test security-related commands"""
        print(f"\n{Colors.MAGENTA}{'='*60}")
        print(f"🔒 Testing Security Commands")
        print(f"{'='*60}{Colors.RESET}")
        
        # Nmap
        self.test_command(
            "nmap_localhost",
            "nmap -F 127.0.0.1",
            expect_success=True,
            timeout=60
        )
        
        # Netcat
        self.test_command(
            "netcat_version",
            "nc -h 2>&1 || ncat --version",
            expect_success=True
        )
        
        # OpenSSL
        self.test_command(
            "openssl_version",
            "openssl version",
            expect_success=True
        )
        
        # Hashcat
        self.test_command(
            "hashcat_version",
            "hashcat --version",
            expect_success=False,  # May not be installed
        )
        
        # SSH
        self.test_command(
            "ssh_version",
            "ssh -V",
            expect_success=True
        )
    
    def test_system_commands(self):
        """Test system commands"""
        print(f"\n{Colors.MAGENTA}{'='*60}")
        print(f"💻 Testing System Commands")
        print(f"{'='*60}{Colors.RESET}")
        
        self.test_command(
            "whoami",
            "whoami",
            expect_success=True
        )
        
        self.test_command(
            "hostname",
            "hostname",
            expect_success=True
        )
        
        self.test_command(
            "uname",
            "uname -a",
            expect_success=True
        )
        
        self.test_command(
            "ps",
            "ps aux | head -5",
            expect_success=True
        )
        
        self.test_command(
            "netstat",
            "netstat -tuln 2>/dev/null || ss -tuln",
            expect_success=True
        )
        
        self.test_command(
            "df",
            "df -h",
            expect_success=True
        )
        
        self.test_command(
            "free",
            "free -h 2>/dev/null || vm_stat",
            expect_success=True
        )
    
    def test_python_environment(self):
        """Test Python environment"""
        print(f"\n{Colors.MAGENTA}{'='*60}")
        print(f"🐍 Testing Python Environment")
        print(f"{'='*60}{Colors.RESET}")
        
        self.test_command(
            "python_version",
            "python3 --version",
            expect_success=True,
            expect_output="3."
        )
        
        self.test_command(
            "pip_version",
            "pip3 --version || pip --version",
            expect_success=True
        )
        
        # Test imports
        test_imports = [
            ("requests", "import requests; print('OK')"),
            ("scapy", "import scapy; print('OK')"),
            ("paramiko", "import paramiko; print('OK')"),
            ("psutil", "import psutil; print('OK')"),
            ("flask", "import flask; print('OK')"),
            ("cryptography", "import cryptography; print('OK')"),
            ("colorama", "import colorama; print('OK')"),
            ("dnspython", "import dns; print('OK')"),
        ]
        
        for name, code in test_imports:
            self.test_command(
                f"import_{name}",
                f"python3 -c \"{code}\"",
                expect_success=False  # Some may not be installed
            )
    
    def test_lynx_spider_module(self):
        """Test LYNX-SPIDER-V1 module"""
        print(f"\n{Colors.MAGENTA}{'='*60}")
        print(f"🕷️ Testing LYNX-SPIDER-V1 Module")
        print(f"{'='*60}{Colors.RESET}")
        
        # Check if main file exists
        main_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'lynx_spider.py')
        
        if not os.path.exists(main_file):
            print(f"{Colors.YELLOW}⚠️  lynx_spider.py not found, skipping module tests{Colors.RESET}")
            self.skipped += 5
            return
        
        self.test_command(
            "lynx_syntax_check",
            f"python3 -m py_compile {main_file}",
            expect_success=True
        )
        
        self.test_command(
            "lynx_import_check",
            f"python3 -c \"import sys; sys.path.insert(0, '{os.path.dirname(main_file)}'); "
            f"import lynx_spider; print('OK')\"",
            expect_success=False,  # May fail due to missing deps
        )
    
    def test_docker(self):
        """Test Docker environment"""
        print(f"\n{Colors.MAGENTA}{'='*60}")
        print(f"🐳 Testing Docker Environment")
        print(f"{'='*60}{Colors.RESET}")
        
        self.test_command(
            "docker_version",
            "docker --version",
            expect_success=False  # Docker may not be installed
        )
        
        self.test_command(
            "docker_compose_version",
            "docker-compose --version || docker compose version",
            expect_success=False
        )
        
        self.test_command(
            "dockerfile_exists",
            "test -f Dockerfile && echo 'exists'",
            expect_success=False
        )
    
    def test_configuration(self):
        """Test configuration files"""
        print(f"\n{Colors.MAGENTA}{'='*60}")
        print(f"⚙️  Testing Configuration Files")
        print(f"{'='*60}{Colors.RESET}")
        
        files_to_check = [
            ("requirements.txt", "test -f requirements.txt"),
            ("Dockerfile", "test -f Dockerfile"),
            ("docker-compose.yml", "test -f docker-compose.yml"),
            (".gitlab-ci.yml", "test -f .gitlab-ci.yml"),
            ("install.sh", "test -f install.sh"),
            ("install.bat", "test -f install.bat"),
            ("install.ps1", "test -f install.ps1"),
        ]
        
        for name, cmd in files_to_check:
            self.test_command(
                f"file_{name}",
                cmd,
                expect_success=False
            )
    
    def run_all_tests(self):
        """Run all test suites"""
        self.print_banner()
        
        print(f"{Colors.YELLOW}Starting comprehensive test suite...{Colors.RESET}")
        print(f"Verbose: {self.verbose}")
        print(f"Timeout: {self.timeout}s")
        
        start_time = time.time()
        
        self.test_system_commands()
        self.test_network_commands()
        self.test_python_environment()
        self.test_security_commands()
        self.test_lynx_spider_module()
        self.test_docker()
        self.test_configuration()
        
        total_time = time.time() - start_time
        
        # Print summary
        print(f"\n{Colors.CYAN}{'='*60}")
        print(f"📊 Test Summary")
        print(f"{'='*60}{Colors.RESET}")
        
        print(f"\n  {Colors.GREEN}✅ Passed: {self.passed}{Colors.RESET}")
        print(f"  {Colors.RED}❌ Failed: {self.failed}{Colors.RESET}")
        print(f"  {Colors.YELLOW}⏭️  Skipped: {self.skipped}{Colors.RESET}")
        print(f"  ⏱️  Total time: {total_time:.2f}s")
        
        total = self.passed + self.failed
        if total > 0:
            pass_rate = (self.passed / total) * 100
            print(f"\n  Pass rate: {pass_rate:.1f}%")
        
        # Save results
        self.save_results()
        
        return self.failed == 0
    
    def save_results(self):
        """Save test results to JSON"""
        output_file = f"test_results_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        
        report = {
            'timestamp': datetime.now().isoformat(),
            'summary': {
                'passed': self.passed,
                'failed': self.failed,
                'skipped': self.skipped,
                'total': self.passed + self.failed + self.skipped
            },
            'results': self.results
        }
        
        with open(output_file, 'w') as f:
            json.dump(report, f, indent=2)
        
        print(f"\n  📄 Results saved to: {output_file}")


def main():
    parser = argparse.ArgumentParser(
        description='LYNX-SPIDER-V1 Command Test Suite',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 test-commands.py                    # Run all tests
  python3 test-commands.py --verbose          # Run with verbose output
  python3 test-commands.py --timeout 60       # Set timeout to 60s
  python3 test-commands.py --network-only     # Run network tests only
        """
    )
    
    parser.add_argument('-v', '--verbose', action='store_true',
                       help='Verbose output')
    parser.add_argument('-t', '--timeout', type=int, default=30,
                       help='Command timeout in seconds (default: 30)')
    parser.add_argument('--network-only', action='store_true',
                       help='Run network tests only')
    parser.add_argument('--security-only', action='store_true',
                       help='Run security tests only')
    parser.add_argument('--system-only', action='store_true',
                       help='Run system tests only')
    parser.add_argument('--all', action='store_true',
                       help='Run all tests (default)')
    
    args = parser.parse_args()
    
    tester = CommandTester(verbose=args.verbose, timeout=args.timeout)
    
    if args.network_only:
        tester.print_banner()
        tester.test_network_commands()
    elif args.security_only:
        tester.print_banner()
        tester.test_security_commands()
    elif args.system_only:
        tester.print_banner()
        tester.test_system_commands()
    else:
        tester.run_all_tests()
    
    # Exit with appropriate code
    sys.exit(0 if tester.failed == 0 else 1)


if __name__ == '__main__':
    main()

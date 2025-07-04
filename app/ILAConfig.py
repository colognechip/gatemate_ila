#################################################################################################
#    << CologneChip GateMate ILA control program (ILAcop) - ILA configuration >>                #
#    The following Python code configures the gateware of the ILA for the GateMate FPGA.        #
# ********************************************************************************************* #
#    Copyright (C) 2023 Cologne Chip AG <support@colognechip.com>                               #
#    Developed by Dave Fohrn                                                                    #
#                                                                                               #
#    This program is free software: you can redistribute it and/or modify                       #
#    it under the terms of the GNU General Public License as published by                       #
#    the Free Software Foundation, either version 3 of the License, or                          #
#    (at your option) any later version.                                                        #
#                                                                                               #
#    This program is distributed in the hope that it will be useful,                            #
#    but WITHOUT ANY WARRANTY; without even the implied warranty of                             #
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                              #
#    GNU General Public License for more details.                                               #
#                                                                                               #
#    You should have received a copy of the GNU General Public License                          #
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.                     #
#                                                                                               #
# ********************************************************************************************* #
#################################################################################################


import glob, os, subprocess, re
import json, traceback
from pyftdi.ftdi import Ftdi
import io
from contextlib import redirect_stdout
from prettytable import PrettyTable
from config import print_table, print_note
import datetime, math, time


def get_files_with_extension(directory_path, extension):
    search_pattern = directory_path + os.path.sep +'*.' + extension
    file_list = glob.glob(search_pattern)
    absolute_paths = [os.path.abspath(file) for file in file_list]
    return absolute_paths


def get_valit_input(output_string):
    try:
        value = input(output_string).lower()
        if value in ['e', 'p']:
            return False, value
        test_val = float(value)
        if test_val >= 0:
            return False, value
        else:
            print("Please enter a value ≥ 0")
            return True, ""
    except Exception as e:
        print(print_note(
            ["Invalid input. Please enter a valid float value.",
             "Exit the config process with 'e'.",
             "Go to previous step with 'p'."
             ],
            " Input ERROR ", '!'))
        return True, ""


def execute_tool(command, output_file, output_log):
    try:
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
        output, error = process.communicate()
        if not os.path.exists(output_file):
            print(
                'error during the execution of command:' + os.linesep + '  ' + command + os.linesep + os.linesep + "Error output:" + os.linesep +
                str(error.decode('utf-8')) + os.linesep + os.linesep + "log:")
            with open(output_log, 'r') as file:
                content = file.read()
                print(content)
            return False
        else:
            return True
    except Exception as e:
        print(e)
        traceback.print_exc()
        return False


def check_and_round_to_next_power_of_two(value):
    if value & (value - 1) == 0:
        return value
    else:
        return 2 ** math.ceil(math.log(value, 2))


def check_and_round_down_to_next_power_of_two(value):
    if value & (value - 1) == 0:
        return value
    else:
        return 2 ** math.floor(math.log(value, 2))



def get_port_idx(request_string, len_ports):
    while True:
        try:
            usr_in = input(request_string).lower()
            if usr_in in ['e', 'p']:
                return False, usr_in
            idx = int(usr_in)
            if 0 <= idx < len_ports:
                return True, idx
            else:
                print("please enter a value in the range 0 - " + str(len_ports - 1))
        except ValueError:
            print(print_note(
                ["Invalid input. Please enter a valid float value.",
                 "Exit the config process with 'e'.",
                 "Go to previous step with 'p'."
                 ],
                " Input ERROR ", '!'))


def insert_line_break(text, character):
    result = []
    while len(text) > 25:
        index = text.rfind(character, 13, 21)
        if index == -1:
            index = 20
        result.append(text[:index + 1])
        text = text[index + 1:]

    if text:
        result.append(text)

    return result


def is_value_present(value, max_BRAM_count):
    for entry in max_BRAM_count:
        if value == entry[0]:
            return True
    return False


def out_signal(signal):
    if signal["Signal_range"] is not None:
        return signal["Signal_type"] + " " + signal["Signal_range"] + " " + signal["Signal_name"]
    else:
        return signal["Signal_type"] + " " + signal["Signal_name"]



def get_size_vec(ranges):
    el = list(map(int, ranges.split(':')))
    if len(el) == 2:
        return len(set(range(el[1], el[0] + 1)))
    else:
        return 1


def load_from_json(file_name, __version__):
    with open(file_name, 'r') as f:
        data = json.load(f)
    ila_config = ILAConfig(__version__)
    ila_config.__dict__.update(data)
    if __version__ != ila_config.ILA_version:
        print(f'Warning: The loaded file was created with a different version of the ILA than the one currently in use to load the configuration. This may lead to compatibility issues.\nFile version: {ila_config.ILA_version}')
    now = datetime.datetime.now()
    ila_config.time_stamp = now.strftime("%y-%m-%d_%H-%M-%S")
    ila_config.found_cc_rst = False
    config_check = True
    if ila_config.ILA_sampling_freq_MHz == "":
        config_check = False
        print("!ERROR! The value 'frequency' is not set")
        print("The string represents the frequency in MHz at which the signals "
              "under test are captured and is a string that contains only a decimal number.")
    return ila_config, config_check


class ILAConfig:
    ILA_version = ""
    SUT_top_name = ""
    explanation_SUT_top_name = ""
    SUT_ccf_file_source = ""
    explanation_SUT_ccf_file_source = ""
    verilog_sources = []
    explanation_verilog_sources = ""
    VHDL_sources = []
    explanation_VHDL_sources = ""
    ILA_sampling_freq_MHz = ""
    explanation_ILA_sampling_freq_MHz = ""
    sample_compare_pattern = 0
    explanation_sample_compare_pattern = ""
    SUT_signals = []
    explanation_SUT_signals = ""
    clk_name = ""
    explanation_clk_name = ""
    external_clk_freq = ""
    explanation_external_clk_freq = ""
    ILA_clk_delay = 2
    explanation_ILA_clk_delay = ""
    ports_DUT = []
    toolchain_info = ""
    DUT_BRAMS_20k = 0
    DUT_BRAMS_40k = 0
    explanation_DUT_BRAMS = ""
    total_size = 0

    def __init__(self, __version__):
        self.ILA_version = __version__
        self.FIFO_SMP_CNT_before = None
        self.explanation_speed = "Configure ILA for best performance. Max Sample Width = 40, the number of samples depends on the sample width."
        self.speed = False
        self.explanation_sample_compare_pattern = "With this parameter, you can toggle the pattern compare function, " \
                                                  "reducing logic use and shortening the critical path when deactivated."
        self.sample_compare_pattern = False
        self.explanation_sync_level = "Determines the number of register levels via which the signals to be analysed are synchronised."
        self.sync_level = 2
        self.explanation_ILA_clk_delay = "here you can set the delay of the sampling frequency. 0 = 0°, 1 = 90°, 2 = 180° and 3 = 270° (default: 2)"
        self.ILA_clk_delay = 2
        self.explanation_ILA_sampling_freq_MHz = "The string represents the frequency in MHz at which the signals " \
                                                 "under test are captured. String that contains only a decimal number."
        self.ILA_sampling_freq_MHz = ""
        self.explanation_SUT_signals = ["This array contains all signals found in the Design under Test.",
                                        {
                                            "explanation_Signal_type": "Signal type. Possible types are: 'wire', or 'reg'",
                                            "explanation_Signal_range": "Size and orientation of the signal vector.",
                                            "explanation_Signal_moduls": "Module where the signal is defined, listed hierarchically.",
                                            "explanation_Signal_name": "Name of the signal.",
                                            "explanation_selected": "Select a signal to be analyzed by the ILA. 'A' = full signal"
                                                                    "width, e.g: '[1:0]' =  area of the vector (The area should"
                                                                    "be within the vector area and orientation), e.g.: '1' = "
                                                                    "individual signal, e.g.: '9, [7:5], 3, [1:0] = any"
                                                                    "combination of areas and individual signals."
                                        }

                                        ]
        self.SUT_signals = []
        self.explanation_external_clk_freq = "defines the external clock frequency"
        self.external_clk_freq = ""
        self.explanation_SUT_top_name = "Name of the top level entity of the design to be tested"
        self.SUT_top_name = ""
        self.explanation_clk_name = "Name of the DUT clk-input port. The clk-source is crucial as it also serves as " \
                                    "the ILA's clk source"
        self.clk_name = None
        self.input_ctrl_signal_name = None
        self.input_ctrl = False
        self.sample_count = None
        self.input_ctrl_size = 0
        self.explanation_opt = "This optimizes the design by deleting all unused signals before signal evaluation."
        self.opt = False
        self.explanation_verilog_sources = "[(paths to the folder containing the Verilog source code files)]"
        self.verilog_sources = []
        self.explanation_VHDL_sources = "[(paths to the folder containing the VHDL source code files)]"
        self.VHDL_sources = []
        self.explanation_make_pll = "This signal decides whether an additional pll should be instantiated; if this value is False, a signal from the DUT must be selected as the clk signal."
        self.make_pll = True
        self.explanation_clk_source = "This signal decides whether an external signal or an internal signal is to be used as the clk source"
        self.ILA_clk_from_DUT = False
        self.explanation_found_init_mem = "defines information about BRAMS initialized from files."
        self.found_init_mem = []
        self.explanation_DUT_BRAMS = "BRAMS in use by the DUT"
        self.DUT_BRAMS_20k = 0
        self.DUT_BRAMS_40k = 0
        self.external_clk_pin = False
        self.external_clk_pin_name = ""
        self.FIFO_MATRIX_DEPH = None
        self.FIFO_IN_SIZE = None
        self.FIFO_MATRIX_size = None
        self.FIFO_DEPH = None
        self.DUT_file_name_flat = None
        self.ports_DUT = []
        self.toolchain_info = ""
        now = datetime.datetime.now()
        self.time_stamp = now.strftime("%y-%m-%d_%H-%M-%S")
        self.reset_name = None
        self.use_cc_rst = False
        # self.combine_external_reset = False
        self.bits_samples_count = None
        self.use_reset_fuction = None
        self.explanation_SUT_ccf_file_source = "Folder containing the .ccf file"
        self.SUT_ccf_file_source = ""
        self.total_size = 0
        self.analyse_signal = False
        self.ILA_signals_mark = []

    def save_to_json(self, file_name=None):
        if file_name is None:
            file_name = 'save_config'+ os.path.sep +'ila_config_' + self.SUT_top_name + "_" + self.time_stamp + '.json'
        with open(file_name, 'w') as f:
            json.dump(self.__dict__, f, indent=4)
        with open("last_upload.txt", 'w') as file:
                file.write(file_name)
        return file_name

    def set_external_clk_freq(self, ex_freq):
        self.external_clk_freq = ex_freq

    def set_ILA_clk_delay(self, clk_delay):
        self.ILA_clk_delay = clk_delay

    def set_ILA_opt(self, opt):
        self.opt = opt

    def set_sync_level(self, sync_level):
        self.sync_level = sync_level

    def set_verilog(self, verilog_source):
        self.verilog_sources = verilog_source

    def string_to_dic(self, signal):
        last = str(signal.group(3))
        sig_name = last.split('=')[0].strip()
        mod_name = ""
        analyse_arr = []
        if self.analyse_signal:
            self.ILA_signals_mark.append(sig_name)
            if signal.group(2) is not None:
                self.total_size += get_size_vec(signal.group(2).strip('[]'))
            else:
                self.total_size += 1
            analyse_arr = ["A"]
            self.analyse_signal = False

        if sig_name.startswith("\\"):
            mod_names = sig_name.split(".")
            sig_name = mod_names[-1]
            del mod_names[-1]
            for mod in mod_names:
                mod_name += mod + "."
    
        if signal.group(2) is not None:
            return {"Signal_type": signal.group(1), "Signal_range": signal.group(2), "Signal_moduls": mod_name,
                    "Signal_name": sig_name,
                    "selected": analyse_arr}
        else:
            return {"Signal_type": signal.group(1), "Signal_range": None, "Signal_moduls": mod_name,
                    "Signal_name": sig_name, "selected": analyse_arr}



    def get_yosys_cmd_verilog(self):
        if len(self.verilog_sources) > 0:
            SUT_files_sources_folder_verilog = []
            SUT_files_sources_folder_verilog_namen = []
            for source in self.verilog_sources:
                if not os.path.exists(source):
                    if not os.path.exists(source):
                        print(print_note(
                            [f"The provided path '{source}' does not exist."
                             ],
                            " Warning ", '!'))
                SUT_files_sources_folder_verilog += get_files_with_extension(source, 'v')
            for Namen in SUT_files_sources_folder_verilog:
                SUT_files_sources_folder_verilog_namen.append(Namen.split(os.path.sep)[-1])
            if len(SUT_files_sources_folder_verilog_namen) == 0:
                print("Error! No verilog file was found in the given folder!" + os.linesep)
                return False, ''
            print(print_note(SUT_files_sources_folder_verilog_namen, " verilog Files ", '#'))
            return True, ' read -sv ' + " ".join(
                SUT_files_sources_folder_verilog) + '; read_verilog -lib -specify +/gatemate/cells_sim.v +/gatemate/cells_bb.v;'
        else:
            return True, ''

    def set_VHDL(self, vhdl_source):
        self.VHDL_sources = vhdl_source

    def set_speed(self, speed):
        self.speed = speed

    def get_yosys_cmd_VHDL(self):
        if len(self.VHDL_sources) > 0:
            SUT_files_sources_folder_vhdl = []
            SUT_files_sources_folder_vhdl_namen = []
            for source in self.VHDL_sources:
                if not os.path.exists(source):
                    print(print_note(
                        [f"The provided path '{source}' does not exist."
                         ],
                        " Warning ", '!'))
                SUT_files_sources_folder_vhdl += get_files_with_extension(source, 'vhd')
                SUT_files_sources_folder_vhdl += get_files_with_extension(source, 'vhdl')
            for Namen in SUT_files_sources_folder_vhdl:
                SUT_files_sources_folder_vhdl_namen.append(Namen.split(os.path.sep)[-1])
            if len(SUT_files_sources_folder_vhdl_namen) == 0:
                print("Error! No VHDL file was found in the given folder!" + os.linesep)
                return False, ''
            print(print_note(SUT_files_sources_folder_vhdl_namen, " vhdl Files ", '#'))
            return True, ' ghdl --warn-no-binding -C --ieee=synopsys ' + " ".join(
                SUT_files_sources_folder_vhdl) + '  -e ' + self.SUT_top_name + ';'
        else:
            return True, ''

    def set_DUT_top(self, SUT_top_name):
        self.SUT_top_name = SUT_top_name

    def set_DUT_ccf(self, ccf_source):
        if not os.path.exists(ccf_source):
            print(print_note(
                [f"The provided path '{ccf_source}' does not exist."
                 ],
                " Warning ", '!'))
            return False
        ccf_file_source = get_files_with_extension(ccf_source, 'ccf')
        if len(ccf_file_source) == 0:
            return False
        else:
            self.SUT_ccf_file_source = ccf_file_source[0]
            print(print_note([self.SUT_ccf_file_source.split(os.path.sep)[-1]], " ccf File ", '#'))
            return True

    def flat_DUT(self, work_dir):
        save_dir = os.getcwd()
        verilog_found, verilog_string = self.get_yosys_cmd_verilog()
        if not verilog_found:
            return False
        vhdl_found, vhdl_string = self.get_yosys_cmd_VHDL()
        if not vhdl_found:
            return False
        self.DUT_file_name_flat = save_dir + os.path.sep + 'config_design' + os.path.sep + self.SUT_top_name + '_' + self.time_stamp + '_flat.v'
        save_gl_dir = os.path.dirname(save_dir)
        log_file = save_gl_dir + os.path.sep + 'log' + os.path.sep + 'yosys_DUT.log'
        from config import YOSYS, YOSYS_GHDL_FLAG
        if self.opt:
            opt_string = 'opt_expr; opt_clean; '
        else:
            opt_string = ''
        if work_dir:
            os.chdir(work_dir)
        yosys_command = YOSYS + ' -l ' + log_file + YOSYS_GHDL_FLAG +' -p "' + verilog_string + \
                        vhdl_string + ' hierarchy -check -top ' + self.SUT_top_name + \
                        '; proc; flatten; tribuf -logic; deminout; ' + opt_string + 'write_verilog ' + \
                        self.DUT_file_name_flat + ' ; ' \
                                                  'check;  alumacc; opt; memory -nomap; opt_clean; ' \
                                                  'memory_libmap -lib +/gatemate/brams.txt; techmap -map +/gatemate/brams_map.v; ' \
                                                  ' stat -width"'
        # print(yosys_command)
        process = subprocess.Popen(yosys_command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
        print("Examine DUT ..." + os.linesep)
        output, error = process.communicate()
        if work_dir:
            os.chdir(save_dir)
        if os.path.exists(self.DUT_file_name_flat):
            return self.find_rams_inuse(log_file)
        else:
            print(f"An error has occurred:{os.linesep}{error.decode('utf-8')}")
            print("yosys cmd: ")
            print(yosys_command)
            return False

    def find_rams_inuse(self, log_file):
        self.DUT_BRAMS_20k = 0
        self.DUT_BRAMS_40k = 0
        pattern_20k = r"CC_BRAM_20K\s+(\d+)"
        pattern_40k = r"CC_BRAM_40K\s+(\d+)"
        with open(log_file, 'r') as file:
            content = file.read()
            match_20k = re.search(pattern_20k, content)
            match_40k = re.search(pattern_40k, content)

            if match_20k:
                self.DUT_BRAMS_20k = int(match_20k.group(1))

            if match_40k:
                self.DUT_BRAMS_40k = int(match_40k.group(1))
        print(print_note(
            ["CC_BRAM_20K in use: " + str(self.DUT_BRAMS_20k),
             "CC_BRAM_40K in use: " + str(self.DUT_BRAMS_40k)
             ],
            " Block RAM in use ", '#'))
        from config import available_BRAM
        if (self.DUT_BRAMS_40k + (self.DUT_BRAMS_20k//2)) > available_BRAM:
            print(print_note(
                ["All available BRAMs are used by the DUT.  ",
                 "The gatemate_ila needs at least one free BRAM.",
                 "The configuration is canceled. "
                 ],
                " Warning ", '!'))
        return True

    def get_DUT_flat_code(self):
        try:
            with open(self.DUT_file_name_flat, 'r') as file:
                lines = file.readlines()
                lines = [line for line in lines]
                return lines
        except FileNotFoundError:
            print(f"File not found: {self.DUT_file_name_flat}")
            return []
        except Exception as e:
            print(f"Error reading file: {e}")
            return []

    def parse_DUT(self, file, config=True ):
        module_instance = "module " + self.SUT_top_name + "("
        found_begin_start = 0
        found_element = {
            "start": None,
            "pll": [],
            "reset": [],
            "end": None

        }
        clk_signal_names_array = []
        self.ILA_signals_mark = []
        in_funktion = False
        in_initial_mem = False
        self.ports_DUT = []
        in_moduls_instance = False
        found_reset = False
        inside_cc_pll = False
        out_clk_value = None
        pll_name = None
        self.analyse_signal = False
        reset_pattern = r'^\s*CC_USR_RSTN\s.*'
        reset_pattern_signal = r"\s*\.USR_RSTN\((.*?)\)"
        function_pattern = r'^\s*function\s.*'
        function_end_pattern = r'^\s*endfunction\s.*'
        out_clk_pattern = re.compile(r"\s*\.OUT_CLK\(\"([^\"]*)\"\)")
        clk_signals_pattern = re.compile(r"\s*\.(CLK0|CLK180|CLK270|CLK90)\(([^)]+)\)")
        pll_name_pattern = re.compile(r"\)\s*([^)]+)\s*\(")
        mem_name_pattern = r"\s*(\w+(\.\w+)*)\s*\[.*?\]\s*=.*?;"
        reset_name = ""
        self.found_init_mem = []
        for code_lines, line in enumerate(file):
            if not in_funktion:
                if "initial begin" == line.strip():
                    found_begin_start = code_lines
                    in_initial_mem = True
                elif re.match(reset_pattern, line):
                    found_reset = True
                    found_begin_start = code_lines
                elif "CC_PLL #" in line:
                    inside_cc_pll = True
                    clk_signal_names_array = []
                elif inside_cc_pll:
                    out_clk_match = out_clk_pattern.search(line)
                    if out_clk_match:
                        out_clk_value = out_clk_match.group(1)
                    else:
                        clk_name_match = pll_name_pattern.search(line)
                        if clk_name_match:
                            pll_name = clk_name_match.group(1)
                        else:
                            clk_signals_match = clk_signals_pattern.search(line)
                            if clk_signals_match:
                                clk_signal_names_array.append(clk_signals_match.group(2))
                            elif ");" in line:
                                inside_cc_pll = False
                                found_element["pll"].append([out_clk_value, clk_signal_names_array, pll_name])

                                print_pll = ["Pll name  = " + pll_name ,
                                             "Frequency = " + out_clk_value + " MHz"]

                                print(print_note(print_pll, " Found PLL instance "))

                elif re.match(function_pattern, line):
                    in_funktion = True
                elif in_initial_mem and "end" == line.strip():
                    in_initial_mem = False
                    if (code_lines - found_begin_start) > 300:
                        found_mem_init = self.check_mem_init(file, found_begin_start)
                        if found_mem_init is not None:
                            for line in range(code_lines - 1, code_lines - 10, -1):
                                match = re.search(mem_name_pattern, file[line])
                                if match:
                                    variable_name = match.group(1)
                                    self.found_init_mem.append([found_begin_start, code_lines, found_mem_init,
                                                                     variable_name])
                                    print_init_mem = ["Mem name:", "  " + variable_name,
                                                      "block RAM file initialisation found:", "Mem file:",
                                                      "  " + found_mem_init["mem_file"]]

                                    print(print_note(print_init_mem, " Init block RAM "))
                                    break

                elif found_reset:
                    if ");" == line.strip():
                        found_reset = False
                        found_element["reset"].append([found_begin_start, code_lines, reset_name])
                        print("########### Found CC_USR_RSTN ###########")
                    else:
                        match = re.search(reset_pattern_signal, line)
                        if match:
                            reset_name = match.group(1)
                elif line.startswith(module_instance):
                    if line.rstrip().endswith(");"):
                        found_element["start"] = [code_lines, code_lines]
                    else:
                        in_moduls_instance = True
                        found_begin_start = code_lines
                elif in_moduls_instance and line.rstrip().endswith(");"):
                    in_moduls_instance = False
                    found_element["start"] = [found_begin_start, code_lines]
                elif "endmodule" == line.strip():
                    found_element["end"] = code_lines
                    self.SUT_signals = sorted(self.SUT_signals, key=lambda x: x["Signal_moduls"])
                    if len(self.ILA_signals_mark) > 0:
                        print(print_note(self.ILA_signals_mark, " ILA Signals from DUT "))
                    return found_element

                else:
                    self.search_DUT_port(line)
                    if config:
                        self.search_DUT_signal(line)
            elif re.match(function_end_pattern, line):
                in_funktion = False


    def check_mem_init(self, file, found_begin_start):
        pattern = r'\s*\(\* src = "(.*?)" \*\)'  # re.compile(r'\(\*\s*src\s*=\s*"(.*?)"\s*\*\)')
        for line in range(found_begin_start - 1, max(found_begin_start - 10, 0) - 1, -1):
            match = re.search(pattern, file[line])
            if match:
                last_path = match.group(1).split('|')[-1]
                last_path = re.sub(r':[^:]*$', '', last_path)
                if last_path.endswith('.v'):
                    return self.search_mem_init_fromr_file(last_path)
        return None

    def search_mem_init_fromr_file(self, path):
        regex = re.compile(r'.*\$readmem(h|b)\s*\(\s*"([^"]+)"\s*,\s*(\w+)')
        with open(path, 'r', encoding='utf-8') as file:
            for line in file:
                match = regex.match(line)
                if match:
                    read_type = match.group(1)
                    filename = match.group(2)
                    memory_name = match.group(3)
                    directory = os.path.dirname(path)
                    mem_file_path = directory + os.path.sep +  filename  # os.path.join(directory, filename)
                    if os.path.isfile(mem_file_path):
                        return {"read_type": read_type, "mem_file": mem_file_path}
                    else:
                        parent_directory = os.path.dirname(directory)
                        file_path = os.path.join(parent_directory, filename)
                        if os.path.isfile(file_path):
                            return {"read_type": read_type, "mem_file": file_path}
                        else:
                            example_path = os.path.join("C:"+os.path.sep+"path"+os.path.sep+"to" +os.path.sep , filename)
                            print(
                                f"The file {filename} was not found in: {os.linesep}{directory} {os.linesep}or {os.linesep}{parent_directory}.")
                            while 1:
                                user_input = input(f"Please enter the absolute path to the file in the correct"
                                                   f" syntax. {os.linesep}If you want to continue without a file, press 'c'."
                                                   f"(e.g., {example_path}):  ").lower()
                                if user_input == 'c':
                                    return {"read_type": read_type, "mem_file": filename}
                                normalized_path = os.path.normpath(user_input.strip())
                                if os.path.isfile(normalized_path):
                                    return {"read_type": read_type, "mem_file": normalized_path}
                                else:
                                    print("the entered file was not found!")
                                    return None


    def search_DUT_port(self, line):
        reset_signals = ["reset", "rst", "res"]
        clk_signals = ["clk", "clock"]
        match_port = re.search(r'^\s*((?:input|output|inout))\s+(\[\d+:\d+\])?\s*(.+)\s*;', line)
        if match_port:
            self.ports_DUT.append(self.string_to_dic(match_port))
            if "input" == self.ports_DUT[-1]["Signal_type"]:
                if any(signal in (self.ports_DUT[-1]["Signal_name"]).lower() for signal in reset_signals) and (
                        self.reset_name is None):
                    self.reset_name = self.ports_DUT[-1]["Signal_name"]

                if any(signal in (self.ports_DUT[-1]["Signal_name"]).lower() for signal in clk_signals) and (
                        self.clk_name is None):
                    self.clk_name = self.ports_DUT[-1]["Signal_name"]
                    self.clk_name_global = self.ports_DUT[-1]["Signal_name"]

    def search_DUT_signal(self, line):
        match = re.search(r"\(\* ILA = 32'd1 \*\)", line)
        match2 = re.search(r"\(\* ila = 1'h1 \*\)", line)
        if match or match2:
            self.analyse_signal = True              
        match_signal = re.search(r'^\s*((?:reg|wire))\s+(\[\d+:\d+\])?\s*(.+)\s*;', line)
        if match_signal:
            match_false = re.search(r'(_\d+_)|\[\d+:\d+\]', match_signal.group(3))
            if not match_false:
                self.SUT_signals.append(self.string_to_dic(match_signal))
        return 

    def print_inputs_DUT(self, no_vectors = False):
        word = ' Inputs DUT "' + self.SUT_top_name + '" '
        table = PrettyTable()
        names = []
        table.field_names = ["#", "type", "range", "Name"]
        select_count = 0
        for port_DUT in self.ports_DUT:
            if "input" == port_DUT["Signal_type"]:
                if port_DUT["Signal_range"] is None:
                    table.add_row([select_count, port_DUT["Signal_type"], 1,
                                   port_DUT["Signal_name"]])
                elif no_vectors == False:
                    table.add_row([select_count, port_DUT["Signal_type"], port_DUT["Signal_range"],
                                   port_DUT["Signal_name"]])
                select_count += 1
                names.append(port_DUT["Signal_name"])
        print_table(word, table)
        return names


    def print_moduls(self, moduls):
        table = PrettyTable()
        table.field_names = ["#", "moduls"]
        table.align["#"] = "r"
        table.align["moduls"] = "l"
        for modul_nr, modul in enumerate(moduls):
            table.add_row([modul_nr, self.SUT_top_name + "." + modul])

        word = " SUT moduls "
        print_table(word, table)


    def print_all_signals(self):
        table = PrettyTable()
        table.field_names = ["#", "name", "range", "selected", "hierarchy"]
        table.align["#"] = "r"
        table.align["hierarchy"] = "l"
        table.align["name"] = "l"

        for select_count, single_signal in enumerate(self.SUT_signals, 1):
            value = single_signal["Signal_range"] if single_signal["Signal_range"] is not None else 1
            sig_mod = insert_line_break(single_signal["Signal_moduls"], '.')
            sig_select = insert_line_break(str(single_signal["selected"]), ',')
            max_length = max(len(sig_mod), len(sig_select))
            while len(sig_mod) < max_length:
                sig_mod.append("")
            while len(sig_select) < max_length:
                sig_select.append("")
            table.add_row([select_count, single_signal["Signal_name"], value, sig_select[0], sig_mod[0]])
            for x in range(1, max_length):
                table.add_row(["", "", "", sig_select[x], " " + sig_mod[x]])

        word = " " + self.SUT_top_name + " "
        print_table(word, table)

    def choose_sampling_frequency(self):
        print(print_note(["The sampling frequency determines the rate at which signals are captured.",
                          "When selecting the frequency, ensure it is harmonious with the DUT's frequency,",
                          " either matching or an integral multiple.",
                          "Recommended max. sampling frequency up to 200MHz.",
                          ],
                         " Note ", '!'))
        input_wrong = True
        while input_wrong:
            input_wrong, maybe_ILA_sampling_freq_MHz = get_valit_input(
                "Choose a sampling frequency (greater than 0, float, in MHz): ")
            if maybe_ILA_sampling_freq_MHz in ['e', 'p']:
                return maybe_ILA_sampling_freq_MHz

        self.ILA_sampling_freq_MHz = maybe_ILA_sampling_freq_MHz

        return ""

    def calk_RAM(self):
        #
        # Cologne Chip FIFO
        #  32K x 1 bit
        # • 16K x 2 bit
        # • 8K x 5 bit
        # • 4K x 10 bit
        # • 2K x 20 bit
        # • 1K x 40 bit

        from config import available_BRAM

        available_40k_BRAMs = available_BRAM - (math.ceil(self.DUT_BRAMS_20k / 2) + self.DUT_BRAMS_40k)
        max_BRAM_count = []
        min_BRAMs_deph = 6
        if self.total_size == 1:
            for i in range(min(available_40k_BRAMs, min_BRAMs_deph)):
                value = (i + 1) * 32768
                max_BRAM_count.append([value, 1, 1, (i + 1), 32768])
        elif self.total_size == 2:
            for i in range(min(available_40k_BRAMs, min_BRAMs_deph)):
                value = (i + 1) * 16384
                max_BRAM_count.append([value, 2, 1, (i + 1), 16384])
        else:
            count_5_bit_width = math.ceil(self.total_size / 5)
            if count_5_bit_width <= 5:
                count_5_bit_deph = available_40k_BRAMs // count_5_bit_width
                for i in range(min(count_5_bit_deph, min_BRAMs_deph)):
                    value = (i + 1) * 8192
                    max_BRAM_count.append([value, 5, count_5_bit_width, (i + 1), 8192])
            if self.total_size > 5:
                count_10_bit_width = math.ceil(self.total_size / 10)
                if count_10_bit_width <= 5:
                    count_10_bit_deph = available_40k_BRAMs // count_10_bit_width
                    for i in range(min(count_10_bit_deph, min_BRAMs_deph)):
                        value = (i + 1) * 4096
                        if not is_value_present(value, max_BRAM_count):
                            max_BRAM_count.append([value, 10, count_10_bit_width, (i + 1), 4096])
            if self.total_size > 15:
                # Einträge für 20-Bit Breite
                count_20_bit_width = math.ceil(self.total_size / 20)
                count_20_bit_deph = available_40k_BRAMs // count_20_bit_width
                if (self.total_size % 20) < 10:
                    for i in range(min(count_20_bit_deph, min_BRAMs_deph)):
                        value = (i + 1) * 2048
                        if not is_value_present(value, max_BRAM_count):
                            max_BRAM_count.append([value, 20, count_20_bit_width,(i + 1), 2048])
            if self.total_size > 30:
                count_40_bit_width = math.ceil(self.total_size / 40)
                count_40_bit_deph = available_40k_BRAMs // count_40_bit_width
                for i in range(min(count_40_bit_deph, min_BRAMs_deph)):
                    value = (i + 1) * 1024
                    if not is_value_present(value, max_BRAM_count):
                        max_BRAM_count.append([value, 40, count_40_bit_width, (i + 1), 1024])
            max_BRAM_count.sort(key=lambda x: x[0])
        if len(max_BRAM_count) == 0:
            count_40_bit_width = math.ceil(self.total_size / 40)
            max_BRAM_count.append([1024, 40, count_40_bit_width, 1, 1024])
        return max_BRAM_count


    def choose_Capture_time(self):
        # Cologne Chip FIFO
        #  32K x 1 bit
        # • 16K x 2 bit
        # • 8K x 5 bit
        # • 4K x 10 bit
        # • 2K x 20 bit
        # • 1K x 40 bit
        if self.speed:
            self.FIFO_MATRIX_DEPH =1
            self.FIFO_MATRIX_size = 1
            if self.total_size == 1:
                self.sample_count = 32768
                self.FIFO_IN_SIZE = 1
            elif self.total_size == 2:
                self.sample_count = 16384
                self.FIFO_IN_SIZE = 2
            elif self.total_size <= 5:
                self.sample_count = 8192
                self.FIFO_IN_SIZE = 5
            elif self.total_size <= 10:
                self.sample_count = 4096
                self.FIFO_IN_SIZE = 10
            elif self.total_size <= 20:
                self.sample_count = 2048
                self.FIFO_IN_SIZE = 20
            elif self.total_size <= 40:
                self.sample_count = 1024
                self.FIFO_IN_SIZE = 40
            print(print_note(
                ["Sample count = " + str(self.sample_count),
                 "Capture duration = " + str(round(self.sample_count / float(self.ILA_sampling_freq_MHz), 2)) + " us"],
                " Capture duration ", '#'))
            return self.choose_smp_before()[1]

        all_configs = self.calk_RAM() # max_BRAM_count.append([samples_5_bit, value, 5, count_5_bit_width])
        print(print_note(
            ["The capture duration must be defined.",
             "The maximum duration depends on:",
             " - available ram  ",
             " - width of the sample  ",
             " - sampling frequency",
             "FIFO Cascade (Width x Depth)",
             "FIFO (Input Width x Depth)"
             ],
            " Note ", '!'))
        complete = False
        while not complete:
            table = PrettyTable()
            table.field_names = ["#", "smp_cnt", "duration [us]", "FIFO Cascade", "FIFO" ]
            for x in range(len(all_configs)):
                table.add_row([x+1, all_configs[x][0], round(all_configs[x][0] / float(self.ILA_sampling_freq_MHz), 2),
                               str(f"{all_configs[x][2]} x {all_configs[x][3]}"), str(f"{all_configs[x][1]} x {all_configs[x][4]}")])
            for field in table.field_names:
                table.align[field] = "r"
            print_table("Please choose one of the following durations: ", table)
            while True:
                input_usr = input(
                    os.linesep + "Total Capture duration (choose between 1 and " + str(
                        len(all_configs)) + "): ").lower()
                if input_usr in ['e', 'p']:
                    return input_usr
                else:
                    try:
                        choice = int(input_usr)
                        if 0 < choice < (len(all_configs) +1):
                            self.sample_count = all_configs[choice-1][0]
                            self.FIFO_MATRIX_DEPH = all_configs[choice-1][3]
                            self.FIFO_IN_SIZE = all_configs[choice-1][1]
                            self.FIFO_MATRIX_size = all_configs[choice-1][2]
                            self.FIFO_DEPH = all_configs[choice-1][4]
                            print(print_note(
                                ["Sample count = " + str(self.sample_count),
                                 "Capture duration = " + str(round(self.sample_count / float(self.ILA_sampling_freq_MHz), 2)) + " us"],
                                " Capture duration ", '#'))
                            break
                        else:
                            print("ERROR! Input out of range!")
                    except Exception as e:
                        print(e)
                        print("ERROR! Invalid Input!")
            complete, input_usr = self.choose_smp_before()
            if input_usr == 'e':
                return input_usr
        return ""



    def choose_smp_before(self):
        pipeline_offset = 3
        while True:
            input_usr = input(
                os.linesep + f'Enter the number of capture samples before trigger activation (between 0 and {self.FIFO_DEPH-10}): '
            )
            if input_usr == 'p':
                return False, input_usr
            elif input_usr == 'e':
                return False, input_usr
            else:
                try:
                    choice = int(input_usr)
                    if 0 <= choice <= (self.FIFO_DEPH-10):
                        self.FIFO_SMP_CNT_before = choice + pipeline_offset
                        print(print_note(
                            ["Sample count = " + input_usr,
                             "Capture duration = " + str(
                                 round(choice / float(self.ILA_sampling_freq_MHz), 2)) + " us"],
                            " Capture duration before Trigger ", '#'))
                        return True, ""
                    else:
                        print("ERROR! Input out of range!")
                except Exception as e:
                    print("ERROR! Invalid Input!")


    def choose_input_ctrl(self):
        note = print_note(
            ["You can override an input or input-vector of your top-level entity using the ILA.",
             "Please note that the input will no longer be connected to the FPGA's IO pins.",
             ],
            " Note ", '!')
        print(note)
        user_input = input(
            os.linesep + "Would you like to implement the input control feature? (y/N): ").lower()
        if user_input == "y":
            names = self.print_inputs_DUT()
            in_state, usr_in = get_port_idx(os.linesep + "Select an input signal: ", len(names))
            if not in_state:
                if usr_in == 'p' or usr_in == 'e':
                    return usr_in
            else:
                self.input_ctrl_signal_name = names[usr_in]
                # get Port Index??
                self.input_ctrl = True
                return usr_in
        else:
            self.input_ctrl = False
            return user_input

    def choose_pattern_compare(self):
        note = print_note(
            ["There are two default triggers that can be set for exactly one signal: ",
             " 'rising edge' and 'falling edge'",
             "There is also an optional trigger: pattern compare",
             "With this option, a pattern can be set across the entire bit width, ",
             " determining for each bit whether it should be '1', '0', or 'dc' ",
             " (don't care) to activate the trigger.",
             "If this function is activated, more hardware is required for the ILA",
             " and the maximum possible sampling frequency may be reduced. "
             ],
            " Note ", '!')
        print(note)
        user_input = input(
            os.linesep + "Would you like to implement the function for comparing bit patterns? (y/N): ").lower()
        if user_input == "y":
            self.sample_compare_pattern = True
        else:
            self.sample_compare_pattern = False
        return user_input

    def user_config_loop(self, found_pll, found_reset):
        print(print_note(["Now you will be guided through the configuration of the ILA.",
                          "Entering 'e' exits the process and generates a configurable",
                          "JSON file for the given DUT.",
                          "Enter 'p' for 'previous' to backtrack a step."], " NOTE ", '!'))
        step = 0
        usr_in = ""
        while step < 6:
            if step == 0:
                usr_in = self.choose_clk_source(found_pll)
                if usr_in == 'e':
                    return False
                elif usr_in == 'p':
                    continue
                else:
                    step += 1

            if step == 1:
                usr_in = self.choose_reset(found_reset)
            elif step == 2:
                usr_in = self.choose_analysed_signals()
            elif step == 3:
                usr_in = self.choose_Capture_time()
            elif step == 4:
                usr_in = self.choose_input_ctrl()
            elif step == 5:
                if self.total_size > 4:
                    usr_in = self.choose_pattern_compare()
                else:
                    print(print_note(
                        ["the pattern compare function can only be implement with a sample width of 8 bit or more"],
                        " pattern compare ", '!'))
                    self.sample_compare_pattern = False

            if usr_in == 'e':  # exit
                return False
            elif usr_in == 'p':  # previous
                step -= 1
                continue
            else:
                step += 1
        return True
    def choose_clk_source(self, found_pll):

        print(print_note(["In the following, a clock source for the ILA should be selected.",
                          "Usually, the same clk signal that clocks the tested signals suffices."],
                         " NOTE ", '!'))

        while True:
            print()
            print("Here are the possible ways to provide a clock to the ILA:" + os.linesep)
            print(" 1 = Use an external clk input signal.")
            print(" 2 = Use an additional PLL with a freely selectable frequency "
                  "(additional net of the global Mesh are required).")
            self.ILA_clk_from_DUT = False
            self.make_pll = False
            self.external_clk_pin = False
            self.clk_name = self.clk_name_global
            if len(found_pll) > 0:
                print(" 3 = Use a signal generated by a PLL from your design.")
                options = 3
            else:
                options = 2
            print()
            response = input(
                "Please choose between 1 and " + str(options) + ": ").lower()
            if response in ['e', 'p']:
                return response
            try:
                selection = int(response)

                if selection == 1 or selection == 2:
                    while True:
                        response = self.choose_external_clk()
                        if response == 'p':
                            break
                        elif response == 'e':
                            return response
                        if selection == 2:
                            usr_in = self.choose_sampling_frequency()
                            if usr_in != 'p':
                                if usr_in != 'e':
                                    self.make_pll = True
                                return usr_in
                        else:
                            if response not in ['e', 'p']:
                                self.ILA_sampling_freq_MHz = self.external_clk_freq
                                return response
                elif selection == options:
                    pll_instances = []
                    pll_signal_names = []
                    count = 0
                    out_pll_signal = ["CLK0", "CLK180", "CLK270", "CLK90" ]
                    for number, pll in enumerate(found_pll):
                        pll_instances.append(pll[2] + ": " + pll[0] + " Mhz")
                        pll_instances += [""]
                        for signal in pll[1]:
                            pll_instances.append(" " + str(count) + " = " + out_pll_signal[count%4])
                            pll_signal_names.append(signal)
                            count += 1
                        pll_instances += [""]
                    print(print_note(pll_instances, " PLL instances signals "))
                    print(os.linesep + "Attention! If you choose an output signal of a PLL that you will not use in"
                                       " your design, an additional net of Global Mesh is required! ")
                    in_state, usr_in = get_port_idx(os.linesep + "Choose a clock signal: ", count)
                    if not in_state:
                        if usr_in == 'p':
                            continue
                        else:
                            return usr_in
                    else:
                        self.clk_name = pll_signal_names[usr_in]
                        self.ILA_clk_from_DUT = True
                        self.ILA_sampling_freq_MHz = found_pll[int(usr_in/4)][0]
                        return
                else:
                    print(os.linesep + "The value entered is not within the valid range."  + os.linesep)
            except ValueError:
                print(os.linesep + "Please enter a valid number." + os.linesep)

    def choose_external_clk(self):

        while True:
            if self.clk_name is not None:
                print(print_note(['Input serves as ILA clk source: "' + self.clk_name + '"'],
                                 " found DUT clk source ", '#'))
                response = input("Do you want to change the clk source? (y:yes/N:no): ").lower()
                if response != 'y':
                    return response
            print()
            response = input("Do you want to select a clk signal from the DUT's inputs? (Y:yes/n:no):  ").lower()
            print()
            if response in ['e', 'p']:
                return response
            if response == 'n':
                self.external_clk_pin_name = input(
                    "Enter a pin to be used as the clk source for the ILA. (e.g. 'IO_SB_A8'): ")
                self.external_clk_pin = True
                self.clk_name = "ILA_clk_new_source"
                return ''
            names = self.print_inputs_DUT(True)
            in_state, usr_in = get_port_idx(os.linesep + "Choose the clock signal: ", len(names))
            if not in_state:
                if usr_in != 'p':
                    return usr_in
            else:
                self.clk_name = names[usr_in]
                return usr_in

    def choose_reset(self, found_reset):
        self.use_reset_fuction = False
        self.use_cc_rst = False
        print(print_note(["The ILA can hold the DUT in reset until capture starts.",
                          "This makes it possible to capture the start process of the DUT.",
                          "Attention, the ila treats the signal as active LOW. "],
                         " User controllable reset ", '!'))
        print("The following options are available:" + os.linesep)
        if self.reset_name:
            print(" 1 = Use an external reset input signal. Potential input found: " + self.reset_name)
        else:
            print(" 1 = Use an external reset input signal.")
        print(" 2 = Deactivate this function.")
        if len(found_reset) > 0:
            options = 3
            print(" 3 = Use the ouput signal from the CC_USR_RSTN primitive in your design. (The functionality of the CC_USR_RSTN primitive is still given).")
        else:
            options = 2
        print()
        while True:
            response = input(
                "Please choose between 1 and " + str(options) + ": ").lower()
            if response in ['e', 'p']:
                return response
            try:
                selection = int(response)
                if selection == 1:
                    if self.reset_name:
                        print()
                        response = input("Would you like to choose a different user controllable input than '"
                                         + self.reset_name + "'? (y:yes/N:no): ").lower()
                        if response == 'p':
                            continue
                        elif response == 'e':
                            return response
                        elif response != 'y':
                            self.use_reset_fuction = True
                            return response
                    names = self.print_inputs_DUT(True)
                    while True:
                        in_state, usr_in = get_port_idx(
                            os.linesep + "Choose a reset input: ",
                            len(names))
                        if not in_state:
                            if usr_in == 'p':
                                break
                            elif usr_in == 'e':
                                return usr_in
                        else:
                            self.reset_name = names[usr_in]
                            self.use_reset_fuction = True
                            return usr_in
                elif selection == 2:
                    self.use_reset_fuction = False
                    self.use_cc_rst = False
                    return response
                elif selection == options:
                    self.use_reset_fuction = True
                    self.use_cc_rst = True
                    return response
                else:
                    print(os.linesep + "The value entered is not within the valid range."  + os.linesep)
            except ValueError:
                print(os.linesep + "Please enter a valid number." + os.linesep)



    def choose_analysed_signals(self):
        from config import available_BRAM
        max_signals = ((available_BRAM*2) - (self.DUT_BRAMS_20k + (self.DUT_BRAMS_40k * 2))) * 20
        if self.speed:
            max_signals = 40

        print(print_note(
            ["You will be prompted to select signals for analysis from those found in your design under test."],
            " NOTE ", '!'))
        signal_choice = -1
        current_modul = self.SUT_signals[0]["Signal_moduls"]
        start_index = 0
        moduls = {}
        for i, signal in enumerate(self.SUT_signals):
            if signal["Signal_moduls"] != current_modul:
                moduls[current_modul] = [start_index, i-1]
                start_index = i
                current_modul = signal["Signal_moduls"]
        moduls[current_modul] = [start_index, i]
        modul_names = list(moduls.keys())
        modul_names.sort()
        module_filter = False
        select_modul = False
        insert_signal = False
        modul_choice = 0

        while signal_choice != 0 or self.total_size == 0:
            if not (module_filter or select_modul):
                print()
                self.print_all_signals()
                print(print_note([str(self.total_size) + " (max. " + str(max_signals) + ")"],
                             " Number of selected bits to be analysed "))
            try:
                if len(modul_names) > 1:
                    if not (module_filter or select_modul):
                        usr_in = input("Select signals to be analyzed (0 = finish, f = filter): ").lower()
                        if usr_in == 'f':
                            select_modul = True
                        elif usr_in in ['e', 'p']:
                            return usr_in
                        else:
                            signal_choice = int(usr_in)
                            if 0 < signal_choice <= len(self.SUT_signals):
                                insert_signal = True
                    if select_modul:
                        print()
                        self.print_moduls(modul_names)
                        print()
                        usr_in = input("Select a module from which you would like to analyze signals: ").lower()
                        print()
                        if usr_in == 'p':
                            select_modul = False
                            continue
                        elif usr_in == 'e':
                            return usr_in, 0
                        else:
                            modul_choice = int(usr_in)
                            if 0 <= modul_choice < len(modul_names):
                                module_filter = True
                                select_modul = False
                            else:
                                print("Value out of range!")
                                continue
                    if module_filter:

                        table = PrettyTable()
                        table.field_names = ["#", "name", "range", "selected"]
                        table.align["#"] = "r"
                        table.align["name"] = "l"
                        new_index = 1
                        for index in range (moduls[modul_names[modul_choice]][0], moduls[modul_names[modul_choice]][1]+1):
                            value = self.SUT_signals[index]["Signal_range"] if self.SUT_signals[index][
                                                                         "Signal_range"] is not None else 1
                            sig_select = insert_line_break(str(self.SUT_signals[index]["selected"]), ',')
                            table.add_row([new_index, self.SUT_signals[index]["Signal_name"], value, sig_select[0]])
                            for x in range(1, len(sig_select)):
                                table.add_row(["", "", "", sig_select[x]])
                            new_index += 1

                        word = " " + modul_names[modul_choice] + " signals "
                        print_table(word, table)
                        print()
                        print(print_note([str(self.total_size) + " (max. " + str(max_signals) + ")"],
                                         " Number of selected bits to be analysed "))
                        usr_in = input("Select signals to be analyzed (0 = finish, f = no filter, c = change filter): ").lower()
                        if usr_in in ['f', 'p']:
                            module_filter = False
                            continue
                        elif usr_in == 'e':
                            return usr_in, 0
                        elif usr_in == 'c':
                            module_filter = False
                            select_modul = True
                            continue
                        else:
                            signal_choice = int(usr_in)
                            if 0 < signal_choice <= new_index:
                                signal_choice += moduls[modul_names[modul_choice]][0]
                                insert_signal = True
                else:
                    usr_in = input("Select signals to be analyzed (0 = finish): ").lower()
                    if usr_in in ['e', 'p']:
                            return usr_in
                    else:
                        signal_choice = int(usr_in)
                        if 0 < signal_choice <= len(self.SUT_signals):
                            insert_signal = True

                if insert_signal:
                    insert_signal = False
                    if self.SUT_signals[signal_choice - 1]["Signal_range"] is None:
                        if len(self.SUT_signals[signal_choice - 1]["selected"]) > 0:
                            self.SUT_signals[signal_choice - 1]["selected"] = []
                            self.total_size -=  1
                        else:
                            self.SUT_signals[signal_choice - 1]["selected"] = ["A"]
                            self.total_size += 1
                    else:
                        if len(self.SUT_signals[signal_choice - 1]["selected"]) > 0:
                            if self.SUT_signals[signal_choice - 1]["selected"][0] == "A":
                                self.total_size -= get_size_vec(
                                    self.SUT_signals[signal_choice - 1]["Signal_range"].strip('[]'))
                            else:
                                for ranges in self.SUT_signals[signal_choice - 1]["selected"]:
                                    self.total_size -= get_size_vec(ranges)
                            self.SUT_signals[signal_choice - 1]["selected"] = []
                        else:
                            selected_one_back, size, ende = self.get_vector_signals(signal_choice)
                            if ende in ['e', 'p']:
                                return ende
                            self.total_size += size
                elif signal_choice > len(self.SUT_signals) or signal_choice < 0:
                    print("Value out of range!")
                elif signal_choice == 0 and self.total_size == 0:
                    print(os.linesep + "Warning! You must select at least one signal!")

                if self.total_size > max_signals:
                    print(print_note(["the number of bits within the sample exceeds the maximum number."],
                                     " Critical warning "))

            except Exception as e:
                print(e)
                traceback.print_exc()
                print(print_note(
                    ["Invalid input. Please enter a valid value.",
                     "Entering 'e' exits the process",
                     "Enter 'p' for 'previous' to backtrack a step."
                     ],
                    " Input ERROR ", '!'))
        return ""

    def create_DUT(self, code_lines, found_element):
        new_code_line = code_lines[:found_element["start"][0]]
        wire_string, all_name, config_note = self.get_analyse_Signals()
        print(print_note(config_note, " Signals under test ", '#'))
        module_instance = "module " + self.SUT_top_name + "("
        replacement_string = module_instance + "ila_sample_dut, "
        import_ioput = []
        map_clk = []
        self.cc_usr_rst_found = False
        if len(found_element["reset"]) > 0:
            self.cc_usr_rst_found = True
            pattern = r"^\s*\(\*.*?\*\)\r?$"
            replacement_string = replacement_string + "ILA_rst, "
            import_ioput.append("input ILA_rst;" + os.linesep)
            code_lines[found_element["reset"][0][0]:(found_element["reset"][0][1]+1)] = \
                ["assign " + found_element["reset"][0][2] + " = ILA_rst;" + os.linesep] + \
                ([""] * (found_element["reset"][0][1] - found_element["reset"][0][0]))
            index = found_element["reset"][0][0] -1
            while True:
                match = re.search(pattern, code_lines[index])
                if match:
                    code_lines[index] = ""
                    index -= 1
                else:
                    break


        if self.ILA_clk_from_DUT:
            replacement_string = replacement_string + "ila_clk_src, "
            map_clk = ["assign ila_clk_src = " + self.clk_name + ';' +  os.linesep]
            import_ioput.append("output ila_clk_src;" + os.linesep)
        code_lines[found_element["start"][0]] = code_lines[found_element["start"][0]].replace(module_instance, replacement_string)
        pointer = (found_element["start"][1] + 1)
        new_code_line += code_lines[found_element["start"][0]:pointer]
        new_code_line += ["output [" + str(self.total_size - 1) + ":0] ila_sample_dut;" + os.linesep] + import_ioput

        for mem_init in self.found_init_mem:
            mem_file_path = mem_init[2]["mem_file"] #.replace('\\', '\\\\')
            # initial $readmemh("file.mem", memory);
            new_code_line += code_lines[pointer:mem_init[0]]
            new_code_line += [' initial $readmem' + mem_init[2]["read_type"] + '("' + mem_file_path + '", ' +
                              mem_init[3] + ' );' + os.linesep]
            pointer = mem_init[1] + 1

        new_code_line += code_lines[pointer:found_element["end"]]

        all_signals = ", ".join(all_name)
        new_code_line += wire_string + ["assign ila_sample_dut = {" + all_signals + "};" + os.linesep] + map_clk
        new_code_line += code_lines[found_element["end"]]

        with open('config_design'+ os.path.sep + self.SUT_top_name + '_' + self.time_stamp + '_flat_ila.v', "w") as file:
            for string in new_code_line:
                file.write(string)

        return

    def get_vector_signals(self, signal_choice):
        find_count = re.search(r"\[(\d+):(\d+)\]",
                               self.SUT_signals[signal_choice - 1]["Signal_range"])
        val_1 = int(find_count.group(1))
        val_2 = int(find_count.group(2))
        if val_1 > val_2:
            direction = 0
        else:
            direction = 1
        try:

            outp = ["Define a range for the vector to be analyzed.",
                    " you can do this in the following ways: ",
                    "  1) Press enter to analyze the entire vector",
                    "  2) Define an area of the vector. (The area should be within the vector area): ",
                    "       e.g.: '[1:0]'",
                    "  3) Individual signals:",
                    "       e.g.: '1'",
                    "  4) Any combination of areas and individual signals",
                    "       e.g.: '9, [7:5], 3, [1:0]' "]
            if direction == 0:
                outp.append("define Signals in descending order!")
            else:
                outp.append("define Signals in ascending order!")
            print(print_note(outp, " NOTE ", '!'))
            ranges = input(out_signal(self.SUT_signals[signal_choice - 1]) + ": ").lower()
            if ranges in ['e', 'p']:
                return False, 0, ranges
            match = re.findall(r'\d+:\d+|\d+', ranges)
            numbers = re.findall(r'\d+', ranges)
            print()
            if len(numbers) > 0:
                if direction == 0:
                    for x in range(1, len(numbers)):
                        if int(numbers[x - 1]) <= int(numbers[x]):
                            print("The specified order was not followed.")
                            return False, 0, ""
                else:
                    for x in range(1, len(numbers)):
                        if int(numbers[x - 1]) >= int(numbers[x]):
                            print("The specified order was not followed.")
                            return False, 0, ""
                if (int(numbers[0]) > val_1) or (int(numbers[-1]) < val_2):
                    print("the selected signal is not in the vector range")
                    return False, 0, ""

                self.SUT_signals[signal_choice - 1]["selected"] = match
                size_range = 0
                for ranges in match:
                    size_range += get_size_vec(ranges)
                return True, size_range, ""
            elif len(ranges) == 0:
                self.SUT_signals[signal_choice - 1]["selected"] = ["A"]
                return True, get_size_vec(self.SUT_signals[signal_choice - 1]["Signal_range"].strip('[]')), ""
            else:
                print("no valid value was entered")
                return False, 0, ""
        except ValueError:
            # traceback.print_exc()
            print("Invalid input format. Please make your selection as previously explained!")
            return False, 0, ""

    def get_analyse_Signals(self):
        all_name = []
        wire_string = []
        config_note = []
        for index, signal in enumerate(self.SUT_signals):
            if len(signal["selected"]) > 0:
                # rebuild Signal Name
                rebuild_name = signal["Signal_name"]
                if len(signal["Signal_moduls"]) > 0:
                    rebuild_name = signal["Signal_moduls"] + rebuild_name
                new_name = signal["Signal_name"] + "_" + str(index)
                if signal["selected"][0] == "A":
                    all_name.append(new_name)
                    if signal["Signal_range"] is not None:
                        wire_string += ["wire " + signal["Signal_range"] + " " + new_name + ";" + os.linesep,
                                        "assign " + new_name + " = " + rebuild_name + " ;" + os.linesep]
                        config_note.append(signal["Signal_range"] + " " + signal["Signal_name"])
                    else:
                        wire_string += ["wire " + new_name + ";" + os.linesep +  "assign " + new_name + " = " + rebuild_name + " ;" + os.linesep]
                        config_note.append(signal["Signal_name"])

                else:
                    new_name_signal = new_name + "_build"
                    wire_string += ["wire " + signal["Signal_range"] + " " + new_name_signal + ";" + os.linesep,
                                    "assign " + new_name_signal + " = " + rebuild_name + " ;" + os.linesep]
                    for index_2, ranges in enumerate(signal["selected"]):
                        signal_name_new = new_name + "_" + str(index_2)
                        all_name.append(signal_name_new)
                        size_range = get_size_vec(ranges)
                        if size_range > 1:
                            wire_string += ["wire " + "[" + str(size_range - 1) + ":0] " + signal_name_new + " ;" + os.linesep]
                        else:
                            wire_string += ["wire " + signal_name_new + " ;" + os.linesep]

                        wire_string += ["assign " + signal_name_new + " = " + new_name_signal + "[" + ranges + "] ;" + os.linesep]
                        config_note.append(" [" + ranges + "] " + signal["Signal_name"])
        return wire_string, all_name, config_note

    def get_Signals_run(self):
        all_signals = []
        for signal in self.SUT_signals:
            if len(signal["selected"]) > 0:
                if signal["selected"][0] == "A":
                    if signal["Signal_range"] is not None:
                        all_signals.append([signal["Signal_moduls"] + signal["Signal_name"],
                                            get_size_vec(signal["Signal_range"].strip('[]'))])
                    else:
                        all_signals.append([signal["Signal_moduls"] + signal["Signal_name"], 1])
                else:
                    for ranges in signal["selected"]:
                        all_signals.append(
                            [signal["Signal_moduls"] + signal["Signal_name"] + "_" + "_".join(ranges.split(':')),
                             get_size_vec(ranges)])
        all_signals.reverse()
        return all_signals

    def cnt_signals(self):
        self.total_size = 0
        for signal in self.SUT_signals:
            if len(signal["selected"]) > 0:
                if signal["selected"][0] == "A":
                    if signal["Signal_range"] is not None:
                        self.total_size += get_size_vec(signal["Signal_range"].strip('[]'))
                    else:
                        self.total_size += 1
                else:
                    for ranges in signal["selected"]:
                        self.total_size += get_size_vec(ranges)



    def set_config_ILA(self):
        start_comment_signals = "// __Place~for~Signals~start__"
        end_comment_signals = "// __Place~for~Signals~ends__"
        start_comment_SUT = "// __Place~for~SUT~start__"
        end_comment_SUT = "// __Place~for~SUT~ends__"
        instance_of_dut = self.SUT_top_name + " DUT ("

        if not self.ILA_clk_from_DUT:
            assign_clk = "assign ILA_clk_src = " + self.clk_name + ";" + os.linesep
            connect_clk = ""

        else:
            connect_clk = ".ila_clk_src(ILA_clk_src), "
            assign_clk = ""



        if self.use_reset_fuction and not self.use_cc_rst:
            instance_of_dut = "wire reset_DUT_port;" + os.linesep + "assign reset_DUT_port = (reset_DUT & " \
                              + self.reset_name + ");" + os.linesep \
                              + instance_of_dut + "." + self.reset_name + "(reset_DUT_port), "

        if self.use_cc_rst and self.use_cc_rst:
            instance_of_dut = instance_of_dut + ".ILA_rst(reset_DUT), "
        elif self.cc_usr_rst_found:
            instance_of_dut = "assign reset_DUT = USR_RSTN;" + os.linesep + instance_of_dut + ".ILA_rst(reset_DUT), "

        instance_of_dut = assign_clk + instance_of_dut + connect_clk

        insert_str = os.linesep

        for single_signal in self.ports_DUT:
            if self.input_ctrl and single_signal["Signal_name"] == self.input_ctrl_signal_name:
                if single_signal["Signal_range"] is not None:
                    self.input_ctrl_size = get_size_vec(single_signal["Signal_range"].strip('[]'))
                else:
                    self.input_ctrl_size = 1
                instance_of_dut += "." + single_signal["Signal_name"] + "(" + single_signal["Signal_name"] + "_DUT_ILA_34), "
            else:
                insert_str += out_signal(single_signal) + "," + os.linesep
                if single_signal["Signal_name"] == self.reset_name and self.use_reset_fuction and (not self.use_cc_rst):
                    continue
                instance_of_dut += "." + single_signal["Signal_name"] + "(" + single_signal["Signal_name"] + "), "


        instance_of_dut = instance_of_dut[:-2] + ", .ila_sample_dut(sample));"
        with open('..'+ os.path.sep +'src'+ os.path.sep +'ILA_top.v', "r") as file:
            content = file.read()
            content = content.replace(
                re.search(r"parameter USE_USR_RESET = \d+", content).group(),
                f"parameter USE_USR_RESET = {str(int(self.use_reset_fuction))}")
            content = content.replace(
                re.search(r"parameter USE_PLL = \d+", content).group(),
                f"parameter USE_PLL = {str(int(self.make_pll))}")
            content = content.replace(
                re.search(r"parameter USE_FEATURE_PATTERN = \d+", content).group(),
                f"parameter USE_FEATURE_PATTERN = {str(int(self.sample_compare_pattern))}")
            content = content.replace(
                re.search(r"parameter INPUT_CTRL_size = \d+", content).group(),
                f"parameter INPUT_CTRL_size = {str(self.input_ctrl_size)}")
            hex_value = format(self.FIFO_SMP_CNT_before, 'X')
            content = content.replace(
                re.search(r"parameter \[14:0\] ALMOST_EMPTY_OFFSET = 15'h[0-9A-Fa-f]+", content).group(),
                f"parameter [14:0] ALMOST_EMPTY_OFFSET = 15'h{hex_value}")
            content = content.replace(
                re.search(r"parameter FIFO_IN_WIDTH = \d+", content).group(),
                f"parameter FIFO_IN_WIDTH = {self.FIFO_IN_SIZE}")
            content = content.replace(
                re.search(r"parameter FIFO_MATRIX_WIDTH = \d+", content).group(),
                f"parameter FIFO_MATRIX_WIDTH = {self.FIFO_MATRIX_size}")
            content = content.replace(
                re.search(r"parameter FIFO_MATRIX_DEPH = \d+", content).group(),
                f"parameter FIFO_MATRIX_DEPH = {self.FIFO_MATRIX_DEPH}")
            content = content.replace(
                re.search(r"parameter sample_width = \d+", content).group(),
                f"parameter sample_width = {self.total_size}")
            content = content.replace(
                re.search(r'parameter external_clk_freq = "\d+.?\d+?"', content).group(),
                f'parameter external_clk_freq = "{self.external_clk_freq}"')
            content = content.replace(
                re.search(r'parameter sampling_freq_MHz = "\d+.?\d*?"', content).group(),
                f'parameter sampling_freq_MHz = "{self.ILA_sampling_freq_MHz}"')
            content = content.replace(
                re.search(r"parameter clk_delay = \d+", content).group(),
                f"parameter clk_delay = {str(self.ILA_clk_delay)}")
            content = content.replace(
                re.search(r"parameter SIGNAL_SYNCHRONISATION = \d+", content).group(),
                f"parameter SIGNAL_SYNCHRONISATION = {str(self.sync_level)}")
            start_index = content.find(start_comment_signals) + len(start_comment_signals)
            end_index = content.find(end_comment_signals)
            if self.external_clk_pin:
                insert_str = insert_str + 'input ILA_clk_new_source,' + os.linesep
            if start_index != -1 and end_index != -1:
                content = content[:start_index] + insert_str + content[end_index:]
            start_index = content.find(start_comment_SUT) + len(start_comment_SUT)
            end_index = content.find(end_comment_SUT)
            input_ctrl_str = ""
            if self.input_ctrl:
                input_ctrl_str = "reg [INPUT_CTRL_size-1:0] input_ctrl_DUT;" + os.linesep +"wire [INPUT_CTRL_size-1:0] " + self.input_ctrl_signal_name + "_DUT_ILA_34;" + os.linesep + \
                "assign " + self.input_ctrl_signal_name + "_DUT_ILA_34 = input_ctrl_DUT;" + os.linesep
            if start_index != -1 and end_index != -1:
                content = content[:start_index] + os.linesep + input_ctrl_str + instance_of_dut + os.linesep + content[end_index:]
        with open('..'+ os.path.sep +'src'+ os.path.sep +'ILA_top.v', "w") as file:
            file.write(content)

        with open(self.SUT_ccf_file_source, "r") as file:
            all_lines = file.read()

        start_marker = "# // __Place~for~Signals~SUT__"
        ccf_file_ILA_source = get_files_with_extension('..'+ os.path.sep +'src', 'ccf')[0]
        with open(ccf_file_ILA_source, "r") as file:
            content = file.read()
            start_index = content.find(start_marker) + len(start_marker)
            content = content[:start_index] + os.linesep + all_lines
            if self.external_clk_pin:
                content = content + os.linesep + 'Pin_in "ILA_clk_new_source" Loc = "'+self.external_clk_pin_name +\
                          '" | SCHMITT_TRIGGER=true;'

        with open(ccf_file_ILA_source, "w") as file:
            file.write(content)

    def executing_toolchain(self):
        try:
            from config import YOSYS, PR, PR_FLAGS, YOSYS_FLAGS
            save_dir = os.getcwd()
            save_gl_dir = os.path.dirname(save_dir)
            files = get_files_with_extension('..'+ os.path.sep +'src', 'v') + get_files_with_extension('..'+ os.path.sep +'src'+ os.path.sep +'storage', 'v')
            files.append(save_dir + os.path.sep +'config_design'+ os.path.sep + self.SUT_top_name + '_' + self.time_stamp + '_flat_ila.v')
            all_files = " ".join(files)
            log_file = save_gl_dir + os.path.sep +'log'+ os.path.sep +'yosys.log'
            output_file_yosys = save_gl_dir + os.path.sep +'net'+ os.path.sep +'ila_top_synth' + self.time_stamp + '.v'
            yosys_command = YOSYS + ' -l ' + log_file + ' -p "read -sv ' + all_files + \
                            '; synth_gatemate -top ila_top ' + YOSYS_FLAGS + ' -vlog ' + output_file_yosys + '"'
            print("Execute Synthesis..." + os.linesep + "Output permanently saved to: " + log_file)
            if not execute_tool(yosys_command, output_file_yosys, log_file):
                return False
            output_file_p_r = save_gl_dir + os.path.sep +'p_r_out'+ os.path.sep +'ila_top_' + self.time_stamp
            ccf_file_ila_source = get_files_with_extension('..'+ os.path.sep +'src', 'ccf')[0]
            log_file = save_gl_dir + os.path.sep +'log'+ os.path.sep +'impl.log'
            p_r_command = PR + ' -i ' + output_file_yosys + ' -o ' + output_file_p_r + ' ' + PR_FLAGS + ' -ccf ' + \
                          ccf_file_ila_source + '  > ' + log_file
            time.sleep(3)
            print(os.linesep + "Execute Implementation..." + os.linesep + "Output permanently saved to: " + log_file)
            if not execute_tool(p_r_command, output_file_p_r + '_00.cfg', log_file):
                return False
            self.toolchain_info = output_file_p_r + '_00.cfg'
            time.sleep(5)

            return True
        except Exception as e:
            traceback.print_exc()
            return False

    def upload(self):
        save_dir = os.getcwd()
        save_gl_dir = os.path.dirname(save_dir)
        from config import CON_DEVICE
        if CON_DEVICE != 'oli':
            with io.StringIO() as buf, redirect_stdout(buf):
                Ftdi.show_devices()
                output = buf.getvalue()
            if not ("ftdi://" in output):
                print("No device found!")
                print(
                "Please connect the device and restart the program." + os.linesep + "Your config is save, simply restart with: "
                + os.linesep + "python3 ILAcop.py start")
                return False
            from config import CON_LINK
            from pyftdi.spi import SpiController
            spi = SpiController()
            spi.configure(CON_LINK, turbo=True)
            gpio = spi.get_gpio()
            if CON_DEVICE == 'evb':
                gpio.set_direction(pins=0x09F0, direction=0x0110)
                gpio.write(0x0000)
                time.sleep(0.01)
                gpio.write(0x0010)
                time.sleep(0.01)
            elif CON_DEVICE == 'pgm':
                gpio.set_direction(pins=0x17F0, direction=0x1710)
                gpio.write(0x0000)
                time.sleep(0.01)
                gpio.write(0x0010)
                time.sleep(0.01)
            spi.close()
        else:
            import usb.core
            from config import DIRTYJTAG_VID, DIRTYJTAG_PID, DIRTYJTAG_CMD, DIRTYJTAG_SIG, DIRTYJTAG_WRITE_EP, DIRTYJTAG_TIMEOUT
            dev = usb.core.find(idVendor=DIRTYJTAG_VID, idProduct=DIRTYJTAG_PID)
            if dev is None:
                raise ValueError("device not found")
                return False
            if os.name == 'nt':  # for Windows
                dev.set_configuration()
            else:  # for Unix (Linux, MacOS, etc.)
                dev = usb.core.find(idVendor=DIRTYJTAG_VID, idProduct=DIRTYJTAG_PID)
                if dev is None:
                    print("Device not found. Make sure that it is connected and that the VID/PID are correct.")
                    return None
                try:
                    dev.set_configuration()
                except usb.core.USBError as e:
                    print("Error configuring the device")
                    for cfg in dev:
                        for intf in cfg:
                            if dev.is_kernel_driver_active(intf.bInterfaceNumber):
                                try:
                                    dev.detach_kernel_driver(intf.bInterfaceNumber)
                                    print(f"Kernel driver for interface {intf.bInterfaceNumber} disconnected.")
                                except usb.core.USBError as e:
                                    print(f"Error when disconnecting the kernel driver for interface {intf.bInterfaceNumber}: {e}")
                    dev.set_configuration()
                except Exception as e:
                    return False
            buf = bytearray([
                DIRTYJTAG_CMD["CMD_SETSIG"],
                DIRTYJTAG_SIG["SIG_SRST"],
                0,
                DIRTYJTAG_CMD["CMD_STOP"]
            ])
            try:
                dev.write(DIRTYJTAG_WRITE_EP, buf, DIRTYJTAG_TIMEOUT)
            except usb.core.USBError as e:
                print(f"set Signal failed {e}")
                return -1
            time.sleep(0.01)
            buf = bytearray([
                DIRTYJTAG_CMD["CMD_SETSIG"],
                DIRTYJTAG_SIG["SIG_SRST"],
                DIRTYJTAG_SIG["SIG_SRST"],
                DIRTYJTAG_CMD["CMD_STOP"]
            ])
            try:
                dev.write(DIRTYJTAG_WRITE_EP, buf, DIRTYJTAG_TIMEOUT)
            except usb.core.USBError as e:
                print(f"set Signal failed {e}")
                return -1
            dev.reset()
            time.sleep(0.5)

        first_try = False
        while True:
            print()
            print("Upload to FPGA Board...")
            from config import UPLOAD, UPLOAD_FLAGS
            process = subprocess.Popen(UPLOAD + " " + UPLOAD_FLAGS + self.toolchain_info, stderr=subprocess.PIPE,
                                       stdout=subprocess.PIPE, shell=True)
            output, error = process.communicate()
            ofl_out = output.decode('utf-8')
            ofl_error = error.decode('utf-8')
            with open(save_gl_dir + os.path.sep +'log'+ os.path.sep +'ofl.log', 'w') as file:
                file.write(ofl_out + ofl_error)
            
            
            if ("failed" in ofl_error.lower()) or not("done" in ofl_out.lower()):
                print("Execute openFPGALoader command:")
                print(UPLOAD + " " + UPLOAD_FLAGS + self.toolchain_info)
                print(ofl_out)
                print(os.linesep + "Error: " + os.linesep)
                print(ofl_error)
                if CON_DEVICE == 'oli' and "JTAG init failed" in ofl_error:
                    if not first_try:
                        first_try = True
                    else:
                        print("Please reset the Olimex board manually using the FPGA_RST1 button.")
                        print()
                        eingabe = input("press enter to confirm, enter 'e' to exit: ")
                        if eingabe == 'e':
                            return False
                else:
                    return False
            else:
                return True


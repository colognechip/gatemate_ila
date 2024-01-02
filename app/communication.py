#################################################################################################
#    << CologneChip GateMate ILA control program (ILAcop) - communication >>                    #
#    This program controls the communication with the gateware of the ILA on the FPGA.          #
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

from pyftdi.ftdi import Ftdi
import io, threading, time
from contextlib import redirect_stdout
from pyftdi.spi import SpiController
from time import sleep
import re, os
import traceback
from config import print_note



class ThreadWithReturnValue(threading.Thread):
    def __init__(self, group=None, target=None, name=None, args=(), kwargs={}):
        threading.Thread.__init__(self, group, target, name, args, kwargs)
        self._return = None

    def run(self):
        if self._target is not None:
            self._return = self._target(*self._args, **self._kwargs)

    def join(self, *args):
        threading.Thread.join(self, *args)
        return self._return


def interrupt_input():
    return input()


class Communication:
    def __init__(self, count_bytes, frequency):
        self.count_bytes = count_bytes
        with io.StringIO() as buf, redirect_stdout(buf):
            Ftdi.show_devices()
            output = buf.getvalue()
        devices = re.findall(r'ftdi://\S+', output)
        if len(devices) <= 1:
            print("No device found!"+os.linesep+"To be able to use this programme, you have to connect an FTDI device.")
            print("Please connect a device and restart the programme")
        else:
            try:
                ftdi = Ftdi()
                ftdi.open_from_url(devices[0])
                ftdi.reset()
                ftdi.close()
                spi = SpiController()
                from config import CON_DEVICE, CON_LINK, freq_max
                spi.configure(CON_LINK, turbo=True) #
                if frequency >= freq_max:
                    self.port = spi.get_port(cs=0, freq=freq_max, mode=0)
                else:
                    self.port = spi.get_port(cs=0, freq=frequency, mode=0)
                self.max_payload = spi.PAYLOAD_MAX_LENGTH
                self.gpio = spi.get_gpio()
                if CON_DEVICE == 'evb':
                    self.gpio.set_direction(pins=0x09F0, direction=0x0110) 
                    self.gpio.write(0x0010)
                elif CON_DEVICE == 'pgm':
                    self.gpio.set_direction(pins=0x17F0, direction=0x1710)
                    self.gpio.write(0x0210)
                elif CON_DEVICE == 'cust':
                    from config import cust_gpio_direction_pins, cust_gpio_direction, cust_gpio_write
                    self.gpio.set_direction(pins=cust_gpio_direction_pins, direction=cust_gpio_direction)
                    self.gpio.write(cust_gpio_write)
                sleep(0.1)
                self.port.read(10)
                self.send_reset_ila()
                self.statue = True
                reply = self.port.exchange(bytearray([0b00110000]), 2)
                if not self.send_msg(bytearray([0b00110000])):
                    exit()




            except Exception as exception:
                print("connection failed")
                print(exception)
                print("All found FTDI devices:")
                print(output)
                traceback.print_exc()

    def send_reset_ila(self):
        self.port.exchange(bytearray([42]), 2)

    def reset_FPGA(self):
        from config import CON_DEVICE
        if CON_DEVICE == 'evb':
            self.gpio.write(0x0000)
            sleep(0.01)
            self.gpio.write(0x0010)
            sleep(0.01)
        elif CON_DEVICE == 'pgm':
           self.gpio.write(0x0010)
           sleep(0.01)
           self.gpio.write(0x0210)
           sleep(0.01)
        



    def send_msg(self, send_bytes, debug_inf = True):
        byte_array_send = bytearray(send_bytes)
        #print("send:")
        #print(' '.join(format(byte, '02x') for byte in byte_array_send))
        reply = self.port.exchange(byte_array_send, len(send_bytes)+1)
        #print("receive:")
        #print(' '.join(format(byte, '08b') for byte in reply))
        #print(' '.join(format(byte, '02x') for byte in reply))
        if reply[0] != byte_array_send[-1]:
            if debug_inf:
                print("Communication to the board has failed!")
                print("Ensure that the board is properly connected and configured with the ILA.")
                print("receive: " + str(reply))
                print("send: " + str(byte_array_send))
            return False
        return True



    def read_spi(self, trigger):
        t = ThreadWithReturnValue(target=interrupt_input)
        t.start()
        print(print_note(["Waiting for device. Press Enter to interrupt."],
                         " start Capture "))
        answer_all = []
        count_bytes_all = self.count_bytes +2
        paket_size = int(count_bytes_all / self.max_payload)
        paket_rest = count_bytes_all % self.max_payload
        times_mess = []
        for seq, trig in enumerate(trigger):
            for x in range(2):
                if self.send_msg([trig["activation"]], False):
                    break
            self.send_msg(list(trig["trigger"]))
            self.send_msg([85])
            start_time = time.perf_counter()
            while 1:
                received = self.port.read(1)
                if int(received[0]) == 170:
                    rec_time = time.perf_counter()
                    times_mess.append((rec_time - start_time))
                    start_time = rec_time
                    answer = self.port.exchange(bytearray([170]), paket_rest)
                    for read_package in range(paket_size):
                        answer = answer + self.port.read(self.max_payload)
                    answer_all.append(answer[1:])
                    self.send_reset_ila()
                    break
                elif not t.is_alive():
                    print(print_note(["Stopped by sequence number: " + str(seq)], "user capture stop"))
                    return answer_all, t
        output_time = ["Duration between start and first trigger: " + str(round(times_mess[0], 6)) + " s"]
        times_mess.pop(0)
        for times_m in times_mess:
            output_time.append(("Duration until the next triggering of the trigger: " + str(round(times_m, 6)) + " s"))
        print(print_note(output_time, " Duration between captures "))
        return answer_all, t

    def reset_DUT(self):
        self.port.exchange(bytearray([175]), 2)




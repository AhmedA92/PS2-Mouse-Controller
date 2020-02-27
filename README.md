# PS2-Mouse-Controller
VHDL Mouse Controller  
-The code was implemented with Basys-3 Board in mind, as it utilizes its onboard seven segment display to keep track of the states and show the packets count received from the mouse.
-The first switch on the right (SW0), is the reset button.  
-When a mouse is connected to the usb port of the board, the reset switch is set (reset = 1), after connection, the reset is pulled back to zero.
-The first seven segment is to show the current state the conntroller is at.  
-The states are: start/reset/Ack/BAT/BAT_error/ID_rx/data_reporting/acknowldge_data_reporting_command/data_stream/resend_data.  
-Not all the states should be recheable, and some require physical disconnetion and reconnection of the mouse again.  
-Xilinx ILA core (ila_0) was used for debugging and monitoring the data receieved from the mouse during developement.  

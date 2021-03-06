MODULE ShellSerial; (** AUTHOR "staubesv/be" PURPOSE "Serial port utilities for shell"; *)
(**
 * Note: Based on code of "be"
 *
 * Usage:
 *
 *	ShellSerial.Open [portNbr BitsPerSecond Parity StopBits] ~ opens a shell listening to serial port <portNbr>
 *
 *	ShellSerial.YReceive [[filename] portNbr BitsPerSecond Parity StopBits] ~
 *	ShellSerial.XReceive [[filename] portNbr BitsPerSecond Parity StopBits] ~
 *
 *	Whereas
 *		Parity = "odd"|"even"|"mark"|"space"|"no"
 *		StopBits = "1"|"1.5"|"2"
 *
 * Examples:
 *
 *	ShellSerial.Open 1 115200 no 1 ~
 *	ShellSerial.YReceive ~
 *	ShellSerial.XReceive ~
 *
 * History:
 *
 *	25.06.2007	First release (staubesv)
 *)

IMPORT
	Modules, Kernel, Commands, Streams, Strings, Files, Serials, Shell, XYModem;

CONST

	(* Serial port default settings *)
	DefaultPort = 1;
	DefaultBPS = 115200; DefaultParity = Serials.ParNo; DefaultStop = Serials.Stop1;

	BufferSize = 1024;

	Prompt = "SHELL>";

VAR
	shells : ARRAY Serials.MaxPorts + 1 OF Shell.Shell;

(** Receive a file using Y-modem protocol *)
PROCEDURE YReceive*(context : Commands.Context); (** [[filename] portNbr BitsPerSecond Parity StopBits] ~ *)
VAR
	name : Files.FileName; file : Files.File;
	port : Serials.Port; portNbr, bps, parity, stop, res : LONGINT;
	shellBps, shellData, shellParity, shellStop : LONGINT; isOpen : BOOLEAN;
	recv : XYModem.Receiver; awaitF : BOOLEAN;
	w : Streams.Writer; r : Streams.Reader;
	error: ARRAY 64 OF CHAR;
BEGIN {EXCLUSIVE}
	IF GetXYPars(context, name, portNbr, bps, parity, stop) THEN

		port := Serials.GetPort(portNbr);
		IF port = NIL THEN
			context.error.String("Cannot find port "); context.error.Int(portNbr, 0); context.error.Ln;
			RETURN;
		END;

		IF shells[portNbr] # NIL THEN
			port.GetPortState(isOpen, shellBps, shellData, shellParity, shellStop);
			IF isOpen THEN port.Close; END;
		END;

		port.Open(bps, 8, parity, stop, res);
		IF res # Serials.Ok THEN
			context.error.String("Could not open port "); context.error.Int(portNbr, 0); context.error.Ln;
			RETURN;
		END;

		context.out.String("YReceive "); context.out.String(name); context.out.Ln;
		IF name # "" THEN
			file := Files.New(name); awaitF := FALSE
		ELSE
			file := NIL; awaitF := TRUE
		END;

		NEW(w, port.Send, BufferSize); NEW(r, port.Receive, BufferSize);
		NEW(recv, w, r, file, XYModem.YModem);
		IF ~awaitF THEN
			recv.Await(error)
		ELSE
			recv.AwaitF(file, error)
		END;

		port.Close();

		IF shells[portNbr] # NIL THEN
			port.Open(shellBps, shellData, shellParity, shellStop, res);
			IF res # Serials.Ok THEN
				context.error.String("Warning: Could not re-open shell port "); context.error.Int(portNbr, 0); context.error.Ln;
			END;
		END;

		Wait(1000); (* Give the port open time so we see the output below *)

		IF error # "" THEN
			context.error.String(" "); context.error.String(error)
		ELSE
			Files.Register(file);
			IF awaitF THEN
				file.GetName(name);
				context.out.String("  "); context.out.String(name);
				context.out.String(" ("); context.out.Int(file.Length(), 0); context.out.String(" Bytes"); context.out.String(")");
			END;
			context.out.String(" done.");
		END;
		context.out.Ln;
	END;
END YReceive;

(** Receive a file using X-modem protocol *)
PROCEDURE XReceive*(context : Commands.Context); (** [[filename] portNbr BitsPerSecond Parity StopBits] ~ *)
VAR
	name : Files.FileName; file : Files.File;
	port : Serials.Port; portNbr, bps, parity, stop, res: LONGINT;
	recv : XYModem.Receiver; awaitF : BOOLEAN;
	w : Streams.Writer; r : Streams.Reader;
	shellBps, shellData, shellParity, shellStop : LONGINT; isOpen : BOOLEAN;
	error: ARRAY 64 OF CHAR;
BEGIN
	IF GetXYPars(context, name, portNbr, bps, parity, stop) THEN

		port := Serials.GetPort(portNbr);
		IF port = NIL THEN
			context.error.String("Cannot find port "); context.error.Int(portNbr, 0); context.error.Ln;
			RETURN;
		END;

		IF shells[portNbr] # NIL THEN
			port.GetPortState(isOpen, shellData, shellBps, shellParity, shellStop);
			IF isOpen THEN port.Close; END;
		END;

		port.Open(bps, 8, parity, stop, res);
		IF (res # Serials.Ok) THEN
			context.error.String("Could not open port "); context.error.Int(portNbr, 0); context.error.Ln;
			RETURN;
		END;

		context.out.String("YReceive "); context.out.String(name); context.out.Ln;
		IF name # "" THEN
			file := Files.New(name); awaitF := FALSE
		ELSE
			file := NIL; awaitF := TRUE
		END;

		NEW(w, port.Send, BufferSize); NEW(r, port.Receive, BufferSize);
		NEW(recv, w, r, file, XYModem.XModem);
		IF ~awaitF THEN
			recv.Await(error)
		ELSE
			recv.AwaitF(file, error)
		END;

		port.Close();

		IF shells[portNbr] # NIL THEN
			port.Open(shellBps, shellData, shellParity, shellStop, res);
			IF (res # Serials.Ok) THEN
			END;
		END;

		Wait(1000); (* Give the port open time so we see the output below *)

		IF error # "" THEN
			context.error.String(" "); context.error.String(error)
		ELSE
			Files.Register(file);
			IF awaitF THEN
				file.GetName(name);
				context.out.String("  "); context.out.String(name);
				context.out.String(" ("); context.out.Int(file.Length(), 0); context.out.String(" Bytes"); context.out.String(")");
			END;
			context.out.String(" done.");
		END;
		context.out.Ln;
	END;
END XReceive;

PROCEDURE IsDigit(ch: CHAR): BOOLEAN;
BEGIN
	RETURN (ch >= "0") & (ch <= "9")
END IsDigit;

PROCEDURE Wait(ms: LONGINT);
VAR timer: Kernel.Timer;
BEGIN
	NEW(timer); timer.Sleep(ms);
END Wait;

PROCEDURE GetXYPars(context : Commands.Context; VAR name: ARRAY OF CHAR; VAR port, bps, parity, stop: LONGINT): BOOLEAN;
BEGIN
	port := DefaultPort; bps := DefaultBPS; parity := DefaultParity; stop := DefaultStop;
	IF context.arg.GetString(name) & IsDigit(name[0]) THEN
		Strings.StrToInt(name, port);
		IF (port < 1) OR (port > Serials.MaxPorts) THEN
			context.error.String("wrong port number"); context.error.Ln;
			RETURN FALSE
		END;
		context.arg.SkipWhitespace; context.arg.Int(bps, FALSE);
		context.arg.SkipWhitespace; context.arg.String(name);
		IF name = "odd" THEN
			parity := Serials.ParOdd
		ELSIF name = "even" THEN
			parity := Serials.ParEven
		ELSIF name = "mark" THEN
			parity := Serials.ParMark
		ELSIF name = "space" THEN
			parity := Serials.ParSpace
		ELSIF name # "no" THEN
			context.error.String("wrong parity"); context.error.Ln;
			RETURN FALSE
		END;
		context.arg.SkipWhitespace; context.arg.String(name);
		IF name = "1.5" THEN
			stop := Serials.Stop1dot5
		ELSIF name = "2" THEN
			stop := Serials.Stop2
		ELSIF name # "1" THEN
			context.error.String("wrong stop bits"); context.error.Ln;
			RETURN FALSE
		END;
		context.arg.SkipWhitespace; context.arg.String(name);
	END;
	RETURN TRUE
END GetXYPars;

PROCEDURE GetSerialPortParameters(context : Commands.Context; VAR port, bps, parity, stop: LONGINT): BOOLEAN;
VAR str : ARRAY 32 OF CHAR;
BEGIN
	port := DefaultPort; bps := DefaultBPS; parity := DefaultParity; stop := DefaultStop;
	context.arg.String(str);
	IF IsDigit(str[0]) THEN
		Strings.StrToInt(str, port);
		IF (port < 1) OR (port > Serials.MaxPorts) THEN
			context.error.String("wrong port number"); context.error.Ln();
			RETURN FALSE
		END;
		context.arg.Int(bps, FALSE);
		context.arg.String(str);
		IF str = "odd" THEN
			parity := Serials.ParOdd
		ELSIF str = "even" THEN
			parity := Serials.ParEven
		ELSIF str = "mark" THEN
			parity := Serials.ParMark
		ELSIF str = "space" THEN
			parity := Serials.ParSpace
		ELSIF str # "no" THEN
			context.error.String("wrong parity"); context.error.Ln();
			RETURN FALSE
		END;
		context.arg.String(str);
		IF str = "1.5" THEN
			stop := Serials.Stop1dot5
		ELSIF str = "2" THEN
			stop := Serials.Stop2
		ELSIF str # "1" THEN
			context.error.String("wrong stop bits"); context.error.Ln();
			RETURN FALSE
		END
	END;
	RETURN TRUE
END GetSerialPortParameters;

(** Open a shell listening on the specified <portNbr> *)
PROCEDURE Open*(context : Commands.Context); (** [portNbr BitsPerSecond Parity StopBits] ~ *)
VAR
	port : Serials.Port; portNbr, bps, parity, stop, res : LONGINT;
	w : Streams.Writer; r : Streams.Reader;
BEGIN {EXCLUSIVE}
	IF ~GetSerialPortParameters(context, portNbr, bps, parity, stop) THEN
		portNbr := DefaultPort; bps := DefaultBPS; parity := DefaultParity; stop := DefaultStop
	END;
	port := Serials.GetPort(portNbr);
	IF port # NIL THEN
		IF shells[portNbr] # NIL THEN
			shells[portNbr].Exit; shells[portNbr].AwaitDeath;
			shells[portNbr] := NIL;
			port.Close;
		END;
		port.Open(bps, 8, parity, stop, res);
		IF (res = Serials.Ok) THEN
			NEW(w, port.Send, BufferSize); NEW(r, port.Receive, BufferSize);
			NEW(shells[portNbr], r, w, w, TRUE, Prompt);
		ELSE
			context.error.String("Shell: Could not open port "); context.error.Int(portNbr, 0);
			context.error.String(", res: "); context.error.Int(res, 0); context.error.Ln;
		END;
	ELSE
		context.error.String("Shell: Serial port "); context.error.Int(portNbr, 0); context.error.String(" not found."); context.error.Ln;
	END;
END Open;

PROCEDURE Cleanup;
VAR port : Serials.Port; i : LONGINT;
BEGIN
	FOR i := 0 TO LEN(shells)-1 DO
		IF (shells[i] # NIL) THEN
			shells[i].Exit; shells[i].AwaitDeath;
			shells[i] := NIL;
			port := Serials.GetPort(i);
			IF port # NIL THEN port.Close; END;
		END;
	END;
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
END ShellSerial.

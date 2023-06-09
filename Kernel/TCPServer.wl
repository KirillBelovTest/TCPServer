(* ::Package:: *)

(* ::Chapter:: *)
(*TCP Server*)


(* ::Program:: *)
(*+-------------------------------------------------+*)
(*|                HANDLE PACKET                    |*)
(*|                                                 |*)
(*|              (receive packet)                   |*)
(*|                      |                          |*)
(*|            [get extended packet]                |*)
(*|                      |                          |*)
(*|                <is complete>                    |*)
(*|           yes /             \ no                |*)
(*|    [get message]      [save packet to buffer]   |*)
(*|          |                   /                  |*)
(*|   [invoke handler]          /                   |*)
(*|          |                 /                    |*)
(*|   [send response]         /                     |*)
(*|          |               /                      |*)
(*|    [clear buffer]       /                       |*)
(*|                 \      /                        |*)
(*|                  {next}                         |*)
(*+-------------------------------------------------+*)


(* ::Section::Closed:: *)
(*Requarements*)


Once[If[PacletFind["KirillBelov/Internal"] === {}, PacletInstall["KirillBelov/Internal"]]]; 
Once[If[PacletFind["KirillBelov/Objects"] === {}, PacletInstall["KirillBelov/Objects"]]]; 


(* ::Section::Closed:: *)
(*Begin package*)


BeginPackage["KirillBelov`TCPServer`", {"KirillBelov`Objects`", "KirillBelov`Internal`"}]; 


(* ::Section::Closed:: *)
(*Names*)


TCPServer::usage = 
"TCPServer[opts] TCP server"; 


(* ::Section::Closed:: *)
(*Private context*)


Begin["`Private`"]; 


(* ::Section:: *)
(*Server*)


(* ::Section::Closed:: *)
(*Cosntructor*)


CreateType[TCPServer, {
	"Buffer" -> <||>, 
	"CompleteHandler" -> <||>, 
	"DefaultCompleteHandler" -> $defaultCompleteHandler, 
	"MessageHandler" -> <||>, 
	"DefaultMessageHandler" -> $defaultMessageHandler
}]; 


(* ::Section::Closed:: *)
(*Entrypoint*)


server_TCPServer[packet_Association] := 
Module[{logger, client, extendedPacket, message, result}, 
	client = packet["SourceSocket"]; (*SocketObject[]*)
	extendedPacket = getExtendedPacket[server, client, packet]; (*Association[]*)
	If[extendedPacket["Completed"], 
		message = getMessage[server, client, extendedPacket]; (*ByteArray[]*)
		result = invokeHandler[server, client, message]; (*ByteArray[] | _String | Null*)
		sendResponse[server, client, result]; 
		clearBuffer[server, client], 
	(*Else*)
		savePacketToBuffer[server, client, extendedPacket]
	]; 
]; 


(* ::Section:: *)
(*Internal methods*)


TCPServer /: getExtendedPacket[server_TCPServer, client: SocketObject[uuid_String], packet_Association] := 
Module[{logger, data, dataLength, buffer, last, expectedLength, storedLength, completed, completeHandler, defaultCompleteHandler, extendedPacket}, 
	data = packet["DataByteArray"]; (*ByteArray[]*)
	dataLength = Length[data]; 

	logger = server["Logger"]; 
	logger["received " <> ToString[dataLength] <> " bytes", data]; 

	If[KeyExistsQ[server["Buffer"], uuid] && server["Buffer", uuid]["Length"] > 0, 
		buffer = server["Buffer", uuid]; (*DataStructure[DynamicArray]*)
		last = buffer["Part", -1]; (*Association[]*) 
		expectedLength = last["ExpectedLength"]; 
		storedLength = last["StoredLength"]; , 
	(*Else*)
		completeHandler = server["CompleteHandler"]; (*Association[] | Function[]*)
		defaultCompleteHandler = server["DefaultCompleteHandler"]; (*Function[]*)
		expectedLength = ConditionApply[completeHandler, defaultCompleteHandler][client, data]; 
		storedLength = 0; 
	]; 

	completed = storedLength + dataLength >= expectedLength; 

	(*Return: Association[]*)
	Join[packet, <|
		"Completed" -> completed, 
		"ExpectedLength" -> expectedLength, 
		"StoredLength" -> storedLength + dataLength, 
		"DataLength" -> dataLength
	|>]
]; 


TCPServer /: getMessage[server_TCPServer, client: SocketObject[uuid_String], extendedPacket_Association] := 
If[KeyExistsQ[server["Buffer"], uuid] && server["Buffer", uuid]["Length"] > 0,  
	server["Logger"]["get full message with " <> ToString[extendedPacket["ExpectedLength"]] <> " bytes", extendedPacket]; 
	
	(*Return: _ByteArray*)
	Apply[Join] @ 
	Append[extendedPacket["DataByteArray"]] @ 
	server["Buffer", uuid]["Elements"][[All, "DataByteArray"]], 
(*Else*)
	server["Logger"]["get full message with " <> ToString[extendedPacket["ExpectedLength"]] <> " bytes", extendedPacket]; 

	(*Return: _ByteArray*)
	extendedPacket["DataByteArray"]
]; 


TCPServer /: invokeHandler[server_TCPServer, client_SocketObject, message_ByteArray] := 
Module[{messageHandler, defaultMessageHandler}, 
	server["Logger"]["invoke message handler", message]; 

	messageHandler = server["MessageHandler"]; 
	defaultMessageHandler = server["DefaultMessageHandler"]; 

	(*Return: ByteArray[] | _String | Null*)
	ConditionApply[messageHandler, defaultMessageHandler][client, message]
]; 


TCPServer /: sendResponse[server_TCPServer, client_SocketObject, result: _ByteArray | _String | Null] := 
Switch[result, 
	_String, 
		server["Logger"]["sending " <> ToString[StringLength[result]] <> " bytes response...", result]; 
		WriteString[client, result]; 
		server["Logger"]["response was sended.", result];, 
	
	_ByteArray, 
		server["Logger"]["sending " <> ToString[Length[result]] <> " bytes response...", result]; 
		BinaryWrite[client, result]; 
		server["Logger"]["response was sended.", result];, 
	
	Null, 
		server["Logger"]["handle message without response", result]; 
		Null
]; 


TCPServer /: savePacketToBuffer[server_TCPServer, SocketObject[uuid_String], extendedPacket_Association] := 
If[KeyExistsQ[server["Buffer"], uuid], 
	server["Buffer", uuid]["Append", extendedPacket], 
	server["Buffer", uuid] = CreateDataStructure["DynamicArray", {extendedPacket}]
]; 


TCPServer /: clearBuffer[server_TCPServer, SocketObject[uuid_String]] := 
If[KeyExistsQ[server["Buffer"], uuid], 
	server["Buffer", uuid]["DropAll"]; 
]; 


(* ::Section::Closed:: *)
(*Defaults*)


$defaultCompleteHandler = 
Function[{client, data}, Length[data]]; 


$defaultMessageHandler = 
Function[{client, data}, Close[client]]; 


(* ::Section::Closed:: *)
(*End private context*)


End[]; 


(* ::Section::Closed:: *)
(*End package*)


EndPackage[]; 

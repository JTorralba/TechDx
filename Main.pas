unit Main;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.TabControl,
  FMX.StdCtrls, FMX.Gestures, FMX.Controls.Presentation, FMX.ListView.Types,
  FMX.ListView.Appearances, FMX.ListView.Adapters.Base, FMX.ListView, FMX.Edit,
  FMX.Layouts, FMX.ListBox, IdBaseComponent, IdComponent, IdTCPConnection,
  IdTCPClient, FMX.ScrollBox, FMX.Memo, IDThreadComponent, IDGlobal, System.StrUtils,
  IDCustomTCPServer, IDTCPServer,
  IDStack, IDContext, FMX.Memo.Types;

type
  TTabForm_Main = class(TForm)
    GestureManager_Main: TGestureManager;
    StyleBook_Main: TStyleBook;

    ThreadComponent_Main: TIDThreadComponent;

    TCPClient_Main: TIDTCPClient;
    TCPServer_Main: TIdTCPServer;

    ToolBar_Main: TToolBar;
    Label_Main: TLabel;
    TabControl_Main: TTabControl;

    TabItem_Client: TTabItem;
    Edit_Client_Remote_IP: TEdit;
    Edit_Client_Remote_Port: TEdit;
    Button_Client_Connect: TButton;
    GridPanelLayout_Client: TGridPanelLayout;
    Memo_Client_Console: TMemo;
    Memo_Client_Message: TMemo;
    Button_Client_Send: TButton;

    TabItem_Server: TTabItem;
    Edit_Server_Local_IP: TEdit;
    Edit_Server_Local_Port: TEdit;
    Button_Server_Start: TButton;
    GridPanelLayout_Server: TGridPanelLayout;
    Memo_Server_Console: TMemo;
    Memo_Server_Message: TMemo;
    RadioButton_Server_Echo: TRadioButton;
    RadioButton_Server_Reverse: TRadioButton;
    RadioButton_Server_Normal: TRadioButton;
    Button_Server_Send: TButton;

    TabItem_ANIALI: TTabItem;
    TabItem_ProQA: TTabItem;

    procedure FormGesture(Sender: TObject; const EventInfo: TGestureEventInfo; var Handled: Boolean);

    procedure ThreadComponent_Main_OnRun(Sender: TIDThreadComponent);

    function GetNow(): String;
    function Get_Local_IP(): String;

    procedure FormCreate(Sender: TObject);

    procedure TCPClient_Main_OnConnected(Sender: TObject);
    procedure TCPClient_Main_OnDisconnected(Sender: TObject);
    procedure TCPClient_Main_OnStatus(ASender: TObject; const AStatus: TIDStatus; const AStatusText: String);
    procedure Client_Release(Sender : TObject);
    Procedure Client_Log(Message_Type: String; Message: String; TimeStamp: String; IP_From: String; IP_To: String);
    procedure Button_Client_Connect_OnClick(Sender: TObject);
    procedure Button_Client_Send_OnClick(Sender: TObject);

    Procedure Server_Log(Message_Type: String; Message: String; TimeStamp: String; IP_From: String; IP_To: String);
    procedure Server_Broadcast(Message: String);
    procedure TCPServer_Main_OnExecute(AContext: TIDContext);
    procedure TCPServer_Main_OnConnect(AContext: TIDContext);
    procedure TCPServer_Main_OnDisconnect(AContext: TIDContext);
    procedure TCPServer_Main_OnStatus(ASender: TObject; const AStatus: TIDStatus; const AStatusText: String);
    procedure Button_Server_Start_OnClick(Sender: TObject);
    procedure Button_Server_Send_OnClick(Sender: TObject);
    procedure Quit(Sender: TObject; var Action: TCloseAction);

  private
  public
end;

var TabForm_Main: TTabForm_Main;

var CRLF: String;

var Client_Connected: Boolean;
var Server_Started: Boolean;

var IP_Client: String;
var IP_Remote: String;
var IP_Local: String;

implementation

{$R *.fmx}

procedure TTabForm_Main.FormGesture(Sender: TObject; const EventInfo: TGestureEventInfo; var Handled: Boolean);
begin
{$IFDEF ANDROID}
  case EventInfo.GestureID of
    SGILeft:
    begin
      if TabControl_Main.ActiveTab <> TabControl_Main.Tabs[TabControl_Main.TabCount - 1] then
        TabControl_Main.ActiveTab := TabControl_Main.Tabs[TabControl_Main.TabIndex + 1];
      Handled := True;
    end

    SGIRight:
    begin
      if TabControl_Main.ActiveTab <> TabControl_Main.Tabs[0] then
        TabControl_Main.ActiveTab := TabControl_Main.Tabs[TabControl_Main.TabIndex - 1];
      Handled := True;
    end
  end
{$ENDIF}
end;

function TTabForm_Main.GetNow(): String;
begin
    result := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now);
end;

function TTabForm_Main.Get_Local_IP() : String;
begin
  TIDStack.IncUsage;
  try
    Result := GStack.LocalAddress;
  finally
    TIDStack.DecUsage;
  end;
end;

procedure TTabForm_Main.FormCreate(Sender: TObject);
begin
  Application.Title := 'Technician Diagnostics';
  TabControl_Main.ActiveTab := TabItem_Client;

  CRLF := Chr(13) + Chr(10);

  Client_Connected := False;

  IP_Local := Get_Local_IP();
  Edit_Server_Local_IP.Text := 'Local IP = ' + IP_Local;
  Server_Started := False;
end;

procedure TTabForm_Main.TCPClient_Main_OnConnected(Sender: TObject);
var TimeStamp : String;
begin
  TimeStamp := GetNow();
  ThreadComponent_Main.Active := True;
  Memo_Client_Message.Enabled := True;
  Button_Client_Send.Enabled := True;
  Button_Client_Connect.Text := 'Disconnect';
  Memo_Client_Message.SetFocus();

  IP_Client := TCPClient_Main.Socket.Binding.IP;
  IP_Remote := TCPClient_Main.Socket.Binding.PeerIP;

  Client_Log('ST', 'Connected to server ' + IP_Remote + '.', TimeStamp, IP_Remote, IP_Client);
end;

procedure TTabForm_Main.TCPClient_Main_OnDisconnected(Sender: TObject);
var TimeStamp : String;
begin
  TimeStamp := GetNow();
  ThreadComponent_Main.Active := False;
  Memo_Client_Message.Enabled := False;
  Button_Client_Send.Enabled := False;
  Button_Client_Connect.Text := 'Connect';
  Button_Client_Connect.SetFocus();
  Client_Log('ST', 'Disconnected from server.', TimeStamp, IP_Client, IP_Client);
  IP_Client := '';
  IP_Remote := '';
end;

procedure TTabForm_Main.TCPClient_Main_OnStatus(ASender: TObject; const AStatus: TIDStatus; const AStatusText: String);
var TimeStamp : String;
begin
  TimeStamp := GetNow();
  if (not TCPClient_Main.Connected) and (Client_Connected)
  then
    begin
      Client_Connected := False;
      Client_Log('ST', 'Server terminated connection.', TimeStamp, IP_Client, IP_Client);
      TCPClient_Main_OnDisconnected(ASender);
    end
end;

procedure TTabForm_Main.ThreadComponent_Main_OnRun(Sender: TIDThreadComponent);
var TimeStamp : String;
var Bytes : TIDBytes;
var Message : String;

begin
  if TCPClient_Main.IOHandler.InputBufferIsEmpty
  then
    begin
      TCPClient_Main.IOHandler.CheckForDataOnSource(250);
      TCPClient_Main.IOHandler.CheckForDisconnect;
      if TCPClient_Main.IOHandler.InputBufferIsEmpty
        then
          begin
            Exit;
          end
    end;

  TCPClient_Main.IOHandler.ReadBytes(Bytes, -1);
  TimeStamp := GetNow();
  Message := BytesToString(Bytes,IndyTextEncoding_UTF8);

  IP_Client := TCPClient_Main.Socket.Binding.IP;
  IP_Remote := TCPClient_Main.Socket.Binding.PeerIP;

  Client_Log('RX', Message, TimeStamp, IP_Remote, IP_Client);
end;

procedure TTabForm_Main.Button_Client_Connect_OnClick(Sender: TObject);
var TimeStamp : String;
begin
  TimeStamp := GetNow();
  Client_Connected := not Client_Connected;
  if (Client_Connected)
  then
    begin
      try
        TCPClient_Main.ConnectTimeout := 2500;
        TCPClient_Main.Host := Edit_Client_Remote_IP.Text;
        TCPClient_Main.Port := Edit_Client_Remote_Port.Text.ToInteger;
        TCPClient_Main.Connect();
       except
        on E: Exception do
          begin
            Client_Connected := False;
            Client_Log('ST', '** Connect_Exception **' + CRLF + E.Message, TimeStamp, IP_Client, IP_Client);
          end
      end
    end
  else
    begin
      try
        TCPClient_Main.Disconnect;
      except
        on E: Exception do
          begin
            Client_Connected := False;
            Client_Log('ST', '** Disconnect_Exception **' + CRLF + E.Message, TimeStamp, IP_Client, IP_Client);
            Client_Release(Sender);
          end
      end
    end
end;

procedure TTabForm_Main.Client_Release(Sender: TObject);
begin
  TCPClient_Main_OnDisconnected(Sender);
  TCPClient_Main.IOHandler.InputBuffer.Clear;
  TCPClient_Main.IOHandler.CloseGracefully;
  TCPClient_Main.Disconnect;
end;

procedure TTabForm_Main.Quit(Sender: TObject; var Action: TCloseAction);
begin
  try
    TCPClient_Main.Disconnect;
  except
    on E: Exception do
      begin
        Client_Connected := False;
        Client_Release(Sender);
      end
  end;
  try
    Server_Broadcast('Server initiated termination sequence.');
    TCPServer_Main.Active := False;
  except
    on E: Exception do
      begin
        Server_Started := False;
      end
  end;
end;

procedure TTabForm_Main.Client_Log(Message_Type: String; Message: String; TimeStamp: String; IP_From: String; IP_To: String);
var TCP_Flow : String;
begin
  TThread.Queue(nil, procedure
    begin
      while (LeftStr(Message, 1) = Chr(13)) or (LeftStr(Message, 1) = Chr(10)) do
      begin
        Message := RightStr(Message, Message.Length - 1);
      end;

      while (RightStr(Message, 1) = Chr(13)) or (RightStr(Message, 1) = Chr(10)) do
      begin
        Message := LeftStr(Message, Message.Length - 1);
      end;

      if (Message_Type <> 'ST') then
        begin
          TCP_Flow := IP_From + ' --> ' + IP_To;
        end;

      Memo_Client_Console.Lines.Add(TimeStamp + ' ' + Message_Type + ' ' + Message.Length.ToString() + ' Byte(s) ' + TCP_Flow);
      Memo_Client_Console.Lines.Add('--------------------------------------------------------------------------------');

      Memo_Client_Console.Lines.Add(Message + CRLF);
      Memo_Client_Console.SelStart := Memo_Client_Console.Lines.Text.Length - 1;
    end
  );
end;

procedure TTabForm_Main.Button_Client_Send_OnClick(Sender: TObject);
var TimeStamp : String;
begin
  TimeStamp := GetNow();
  try
    TCPClient_Main.Socket.Write(Memo_Client_Message.Text);
    Client_Log('TX' , Memo_Client_Message.Text, TimeStamp, IP_Client, IP_Remote);
    Memo_Client_Message.Lines.Clear();
  except
    on E: Exception do
      begin
        Client_Connected := False;
        Client_Log('ST', '** Send_Exception **' + CRLF + E.Message, TimeStamp, IP_Client, IP_Client);
        Client_Release(Sender);
      end
  end;
  Memo_Client_Message.SetFocus();
end;

procedure TTabForm_Main.Server_Log(Message_Type: String; Message: String; TimeStamp: String; IP_From: String; IP_To: String);
var TCP_Flow : String;
begin
  TThread.Queue(nil, procedure
    begin
      while (LeftStr(Message, 1) = Chr(13)) or (LeftStr(Message, 1) = Chr(10)) do
      begin
        Message := RightStr(Message, Message.Length - 1);
      end;

      while (RightStr(Message, 1) = Chr(13)) or (RightStr(Message, 1) = Chr(10)) do
      begin
        Message := LeftStr(Message, Message.Length - 1);
      end;

      if (Message_Type <> 'ST') then
        begin
          TCP_Flow := IP_From + ' --> ' + IP_To;
        end;

      Memo_Server_Console.Lines.Add(TimeStamp + ' ' + Message_Type + ' ' + Message.Length.ToString() + ' Byte(s) ' + TCP_Flow);
      Memo_Server_Console.Lines.Add('--------------------------------------------------------------------------------');

      Memo_Server_Console.Lines.Add(Message + CRLF);
      Memo_Server_Console.SelStart := Memo_Server_Console.Lines.Text.Length - 1;
    end
  );
end;

procedure TTabForm_Main.Button_Server_Start_OnClick(Sender: TObject);
var TimeStamp : String;
begin
  TimeStamp := GetNow();
  Server_Started := not Server_Started;
  if (Server_Started)
  then
    begin
      try
        TCPServer_Main.Bindings.Clear();
        TCPServer_Main.Bindings.DefaultPort := Edit_Server_Local_Port.Text.ToInteger();
        {TCPServer_Main.Bindings.Add.Port := Edit_Server_Local_Port.Text.ToInteger();}
        TCPServer_Main.Active := True;

        Memo_Server_Message.Enabled := True;
        RadioButton_Server_Echo.Enabled := True;
        RadioButton_Server_Reverse.Enabled := True;
        RadioButton_Server_Normal.Enabled := True;
        Button_Server_Send.Enabled := True;
        Button_Server_Start.Text := 'Stop';
        Memo_Server_Message.SetFocus();
        Server_Log('ST', 'Server started.', TimeStamp, IP_Local, IP_Local);
       except
        on E: Exception do
          begin
            Server_Started := False;
            Server_Log('ST', '** Start_Exception **' + CRLF + E.Message, TimeStamp, IP_Local, IP_Local);
          end
      end
    end
  else
    begin
      try
        Server_Broadcast('Server initiated termination sequence.');
        TCPServer_Main.Active := False;
      except
        on E: Exception do
          begin
            Server_Started := False;
            Server_Log('ST', '** Stop_Exception **' + CRLF + E.Message, TimeStamp, IP_Local, IP_Local);
          end
      end;
        Memo_Server_Message.Enabled := False;
        RadioButton_Server_Echo.Enabled := False;
        RadioButton_Server_Reverse.Enabled := False;
        RadioButton_Server_Normal.Enabled := False;
        Button_Server_Send.Enabled := False;
        Button_Server_Start.Text := 'Start';
        Button_Server_Start.SetFocus();
        Server_Log('ST', 'Server stopped.', TimeStamp, IP_Local, IP_Local);
    end
end;

procedure TTabForm_Main.TCPServer_Main_OnConnect(AContext: TIdContext);
var TimeStamp : String;
begin
  TimeStamp := GetNow();
  Server_Log('ST', 'Client ' + AContext.Binding.PeerIP + ' connected.', TimeStamp, IP_Local, IP_Local);
  AContext.Connection.IOHandler.Write('Hello ' + AContext.Binding.PeerIP + '!');
end;

procedure TTabForm_Main.TCPServer_Main_OnDisconnect(AContext: TIdContext);
var TimeStamp : String;
begin
  TimeStamp := GetNow();
  Server_Log('ST', 'Client ' + AContext.Binding.PeerIP + ' disconnected.', TimeStamp, IP_Local, IP_Local);
end;

procedure TTabForm_Main.TCPServer_Main_OnExecute(AContext: TIDContext);
var TimeStampRX, TimeStampTX : String;
var Bytes : TIDBytes;
var Message : String;
begin
  AContext.Connection.Socket.ReadBytes(Bytes, -1);
  TimeStampRX := GetNow();
  Message := BytesToString(Bytes,IndyTextEncoding_UTF8);
  Server_Log('RX', Message, TimeStampRX, AContext.Binding.PeerIP, IP_Local);

  if (RadioButton_Server_Echo.IsChecked)
    then
    begin
      TimeStampTX := GetNow();
      AContext.Connection.IOHandler.Write(Message);
      Server_Log('TX', Message, TimeStampTX, IP_LOcal, AContext.Binding.PeerIP);
    end;

    if (RadioButton_Server_Reverse.IsChecked)
    then
    begin
      TimeStampTX := GetNow();
      AContext.Connection.IOHandler.Write(ReverseString(Message));
      Server_Log('TX', ReverseString(Message), TimeStampTX, IP_LOcal, AContext.Binding.PeerIP);
    end;
end;

procedure TTabForm_Main.TCPServer_Main_OnStatus(ASender: TObject; const AStatus: TIdStatus; const AStatusText: String);
var TimeStamp : String;
begin
  TimeStamp := GetNow();
  Server_Log('ST', AStatusText, TimeStamp, IP_Local, IP_Local);
end;

procedure TTabForm_Main.Server_Broadcast(Message: String);
var
    TempList     : TList;
    ContexClient : TIDContext;
    I            : Integer;
    TimeStamp    : String;
begin
    TempList  := TCPServer_Main.Contexts.LockList;

    try
        I := 0;
        while ( i < TempList.Count ) do
          begin
            ContexClient := TempList[I];
            TimeStamp := GetNow();
            ContexClient.Connection.IOHandler.Write(Message);
            Server_Log('TX', Message, TimeStamp, IP_Local, ContexClient.Binding.PeerIP);
            I := I + 1;
        end;
    finally
        TCPServer_Main.Contexts.UnlockList;
    end;
end;

procedure TTabForm_Main.Button_Server_Send_OnClick(Sender: TObject);
var TimeStamp : String;
begin
  TimeStamp := GetNow();
  try
    Server_Broadcast(Memo_Server_Message.Text);
    Memo_Server_Message.Lines.Clear();
  except
    on E: Exception do
      begin
        Server_Log('ST', '** Send_Exception **' + CRLF + E.Message, TimeStamp, IP_Local, IP_Local);
      end
  end;
  Memo_Server_Message.SetFocus();
end;
end.

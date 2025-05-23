﻿// Eduardo - 30/03/2023
unit SQLite;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Threading,
  System.DateUtils,
  System.Generics.Collections,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  FireDAC.Comp.Client,
  FireDAC.Stan.Def,
  FireDAC.DApt,
  FireDAC.Stan.Async,
  FireDAC.Stan.Option;

type
  IConnection = interface
    ['{E816A391-0309-4471-A4C3-3FF4C5090EEC}']
    function Connection: TFDConnection;
    function Query: TFDQuery;
  end;

  TConnectionState = (Livre, Ocupada);

  TConnection = class
    FFDCon: TFDConnection;
    FState: TConnectionState;
    FUso: TDateTime;
  public
    constructor Create(Con: TFDConnection);
    destructor Destroy; override;
  end;

  TIntfConnection = class(TInterfacedObject, IConnection)
  private
    FCon: TConnection;
    FFDQry: TFDQuery;
  public
    constructor Create(Con: TConnection);
    destructor Destroy; override;
    function Connection: TFDConnection;
    function Query: TFDQuery;
  end;

  TPoolStatus = (Iniciando, Iniciado, Parando, Parado);

  TPool = class
  private
    FFile: String;
    FMaxIdle: Integer;
    FMaxConn: Integer;
    FConnetions: TObjectList<TConnection>;
    FThread: ITask;
    FStatus: TPoolStatus;
    function NewConnection(sFile: String): TFDConnection;
    procedure CloseConnections;
  public
    class procedure Start(sFile: String; iMaxConnections: Integer = 50; iMaxIdleTimeout: Integer = 30);
    class procedure Stop;
    class function Instance: IConnection;
  end;

implementation

var
  FPool: TPool;

{ TPool }

function TPool.NewConnection(sFile: String): TFDConnection;
begin
  Result := TFDConnection.Create(nil);
  TFDPhysSQLiteConnectionDefParams(Result.Params).DriverID := 'SQLite';
  TFDPhysSQLiteConnectionDefParams(Result.Params).JournalMode := jmWAL;
  TFDPhysSQLiteConnectionDefParams(Result.Params).Synchronous := snNormal;
  TFDPhysSQLiteConnectionDefParams(Result.Params).LockingMode := lmNormal;
  TFDPhysSQLiteConnectionDefParams(Result.Params).SharedCache := False;

  // \o/ Corrige erro de cortar o script ao meio: https://docwiki.embarcadero.com/RADStudio/Sydney/en/Preprocessing_Command_Text_(FireDAC)
  Result.ResourceOptions.MacroCreate := False;
  Result.ResourceOptions.MacroExpand := False;
  Result.ResourceOptions.EscapeExpand := False;

  Result.UpdateOptions.LockWait := True;
  Result.Connected := True;
  Result.LoginPrompt := False;
  Result.Params.Values['Database'] := sFile;
  Result.Open;
end;

procedure TPool.CloseConnections;
var
  I: Integer;
  Item: TConnection;
  aItens: TArray<TConnection>;
begin
  FPool.FStatus := Iniciado;
  try
    while FPool.FStatus = Iniciado do
    begin
      TMonitor.Enter(FPool);
      try
        aItens := [];
        for I := 0 to Pred(Length(FPool.FConnetions.ToArray)) do
          if (FPool.FConnetions[I].FState = Livre) and (SecondsBetween(Now, FPool.FConnetions[I].FUso) > FPool.FMaxIdle) then
            aItens := aItens + [FPool.FConnetions[I]];

        for Item in aItens do
          FPool.FConnetions.Remove(Item);
      finally
        TMonitor.Exit(FPool);
      end;

      for I := 1 to 5 do
        if FPool.FStatus = Iniciado then
          Sleep(1000);
    end;
  finally
    FPool.FStatus := Parado;
  end;
end;

class procedure TPool.Start(sFile: String; iMaxConnections: Integer = 50; iMaxIdleTimeout: Integer = 30);
begin
  if Assigned(FPool) then
    raise Exception.Create('Pool já iniciado!');

  if iMaxIdleTimeout < 5 then
    raise Exception.Create('Tempo mínimo de conexão é 5 segundos!');

  if iMaxConnections < 1 then
    raise Exception.Create('Quantidade mínima de conexões é 1!');

  FPool := TPool.Create;
  FPool.FConnetions := TObjectList<TConnection>.Create;
  FPool.FFile := sFile;
  FPool.FMaxConn := iMaxConnections;
  FPool.FMaxIdle := iMaxIdleTimeout;
  FPool.FStatus := Iniciando;

  FPool.FThread := TTask.Create(FPool.CloseConnections);
  FPool.FThread.Start;
end;

class function TPool.Instance: IConnection;
var
  I: Integer;
  Item: TConnection;
begin
  if not Assigned(FPool) then
    raise Exception.Create('Pool não iniciado!');

  TMonitor.Enter(FPool);
  try
    repeat
      for I := 0 to Pred(Length(FPool.FConnetions.ToArray)) do
        if FPool.FConnetions[I].FState = Livre then
          Exit(TIntfConnection.Create(FPool.FConnetions[I]));

      if FPool.FConnetions.Count = FPool.FMaxConn then
        Sleep(100)
      else
        Break;
    until False;

    Item := TConnection.Create(FPool.NewConnection(FPool.FFile));
    FPool.FConnetions.Add(Item);
    Result := TIntfConnection.Create(Item);
  finally
    TMonitor.Exit(FPool);
  end;
end;

class procedure TPool.Stop;
begin
  if not Assigned(FPool) then
    Exit;

  FPool.FStatus := Parando;
  TTask.WaitForAll(FPool.FThread, 5000);

  FPool.FConnetions.Clear;
  FreeAndNil(FPool.FConnetions);

  FreeAndNil(FPool);
end;

{ TConnection }

constructor TConnection.Create(Con: TFDConnection);
begin
  FState := Livre;
  FFDCon := Con;
  FUso := Now;
end;

destructor TConnection.Destroy;
begin
  FFDCon.Close;
  FreeAndNil(FFDCon);
  inherited;
end;

{ TIntfConnection }

constructor TIntfConnection.Create(Con: TConnection);
begin
  FCon := Con;
  FCon.FState := Ocupada;
end;

destructor TIntfConnection.Destroy;
begin
  FCon.FUso := Now;
  FCon.FState := Livre;
  if Assigned(FFDQry) then
  begin
    FFDQry.Close;
    FreeAndNil(FFDQry);
  end;
  inherited;
end;

function TIntfConnection.Connection: TFDConnection;
begin
  Result := FCon.FFDCon;
end;

function TIntfConnection.Query: TFDQuery;
begin
  if not Assigned(FFDQry) then
  begin
    FFDQry := TFDQuery.Create(nil);
    FFDQry.FetchOptions.Mode := fmAll;
    FFDQry.CachedUpdates := False;
    FFDQry.Connection := FCon.FFDCon;
  end;

  Result := FFDQry;
end;

end.

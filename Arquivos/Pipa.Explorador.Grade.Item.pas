// Eduardo - 04/11/2024
unit Pipa.Explorador.Grade.Item;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Variants,
  FMX.Types,
  FMX.Graphics,
  FMX.Controls,
  FMX.Forms,
  FMX.Dialogs,
  FMX.StdCtrls,
  FMX.Objects,
  Pipa.Tipos, FMX.Gestures;

type
  TAcaoItemLista = (Marcar, Desmarcar);

  TAparencia = record
    Icone: String;
    TemMiniatura: Boolean;
  end;

  TItemLista = class(TFrame)
    rtgItem: TRectangle;
    txtNome: TText;
    clSelecao: TCircle;
    pthSelecao: TPath;
    tmrMiniatura: TTimer;
    GestureManager: TGestureManager;
    procedure rtgItemMouseEnter(Sender: TObject);
    procedure rtgItemMouseLeave(Sender: TObject);
    procedure rtgItemMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
    procedure rtgItemGesture(Sender: TObject; const EventInfo: TGestureEventInfo; var Handled: Boolean);
    procedure clSelecaoClick(Sender: TObject);
    procedure tmrMiniaturaTimer(Sender: TObject);
    procedure rtgItemTap(Sender: TObject; const Point: TPointF);
    procedure clSelecaoTap(Sender: TObject; const Point: TPointF);
  private
    FImage: TControl;
    FClick: TProc<TItem>;
    FSelecionar: TProc<TAcaoItemLista, TItem>;
    FAtual: TItem;
    FMiniatura: TFunc<TItem, TBytes>;
    procedure ExibirMiniatura(Dados: TBytes);
  public
    class function New(const AOwner: TComponent; Largura: Integer; const Atual: TItem; const Icone: String; const Miniatura: TFunc<TItem, TBytes>; const Click: TProc<TItem>; const Selecionar: TProc<TAcaoItemLista, TItem>): TItemLista;
    destructor Destroy; override;
  end;

implementation

uses
  System.StrUtils,
  System.IOUtils,
  System.Skia,
  System.Threading,
  FMX.Skia,
  Pipa.Miniatura;

{$R *.fmx}

{ TItemLista }

var
  FCompCount: Integer;

class function TItemLista.New(const AOwner: TComponent; Largura: Integer; const Atual: TItem; const Icone: String; const Miniatura: TFunc<TItem, TBytes>; const Click: TProc<TItem>; const Selecionar: TProc<TAcaoItemLista, TItem>): TItemLista;
begin
  AtomicIncrement(FCompCount);

  Result := TItemLista.Create(AOwner);
  Result.Name := TItemLista.ClassName + FCompCount.ToString;
  Result.Width := Largura;
  Result.FAtual := Atual;
  Result.FClick := Click;
  Result.FSelecionar := Selecionar;
  Result.FMiniatura := Miniatura;
  Result.clSelecao.Visible := False;
  Result.txtNome.Text := Atual.Nome;

  if Assigned(Miniatura) then
    Result.tmrMiniaturaTimer(Result.tmrMiniatura);

  if not Assigned(Miniatura) or Result.tmrMiniatura.Enabled then
  begin
    Result.FImage := TSkSvg.Create(Result.rtgItem);
    with Result.FImage do
    begin
      Parent := Result.rtgItem;
      Align := TAlignLayout.Client;
      HitTest := False;
      Size.PlatformDefault := False;
      TSkSvg(Result.FImage).Svg.Source := Icone;
    end;
  end;

  TFmxObject(AOwner).AddObject(Result);

  Result.Align := TAlignLayout.Left;
  Result.Position.X := Pred(AOwner.ComponentCount) * 100;
end;

procedure TItemLista.clSelecaoTap(Sender: TObject; const Point: TPointF);
begin
  clSelecao.Visible := False;
  FSelecionar(TAcaoItemLista.Desmarcar, FAtual);
end;

procedure TItemLista.rtgItemTap(Sender: TObject; const Point: TPointF);
begin
  if clSelecao.Visible then
    clSelecaoTap(clSelecao, TPoint.Create(Round(0), Round(0)))
  else
    FClick(FAtual);
end;

procedure TItemLista.rtgItemGesture(Sender: TObject; const EventInfo: TGestureEventInfo; var Handled: Boolean);
begin
  if EventInfo.GestureID = igiLongTap then
  begin
    clSelecao.Visible := not clSelecao.Visible;
    if clSelecao.Visible then
      FSelecionar(TAcaoItemLista.Marcar, FAtual)
    else
      FSelecionar(TAcaoItemLista.Desmarcar, FAtual);

    Handled := True;
  end;
end;

procedure TItemLista.clSelecaoClick(Sender: TObject);
begin
  clSelecaoTap(clSelecao, TPoint.Create(Round(0), Round(0)));
end;

procedure TItemLista.rtgItemMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
{$IFNDEF ANDROID}
var
  EventInfo: TGestureEventInfo;
  Handled: Boolean;
{$ENDIF}
begin
  {$IFNDEF ANDROID}
  case Button of
    TMouseButton.mbLeft:
    begin
      rtgItemTap(rtgItem, TPoint.Create(Round(X), Round(Y)));
    end;
    TMouseButton.mbRight:
    begin
      EventInfo := Default(TGestureEventInfo);
      EventInfo.GestureID := igiLongTap;
      rtgItemGesture(rtgItem, EventInfo, Handled);
    end;
    TMouseButton.mbMiddle:;
  end;
  {$ENDIF}
end;

procedure TItemLista.rtgItemMouseEnter(Sender: TObject);
begin
  TRectangle(Sender).Fill.Color := TAlphaColorF.Create(204 / 255, 232 / 255, 255 / 255).ToAlphaColor;
end;

procedure TItemLista.rtgItemMouseLeave(Sender: TObject);
begin
  TRectangle(Sender).Fill.Color := TAlphaColorRec.Null;
end;

procedure TItemLista.tmrMiniaturaTimer(Sender: TObject);
var
  Bytes: TBytes;
begin
  tmrMiniatura.Enabled := False;

  Bytes := FMiniatura(FAtual);
  if Length(Bytes) > 0 then
    ExibirMiniatura(Bytes)
  else
    tmrMiniatura.Enabled := True;
end;

procedure TItemLista.ExibirMiniatura(Dados: TBytes);
var
  ss: TStringStream;
begin
  if Assigned(FImage) then
    FImage.Free;

  FImage := TImage.Create(rtgItem);
  with FImage do
  begin
    Parent := rtgItem;
    Align := TAlignLayout.Client;
    HitTest := False;
    Size.PlatformDefault := False;

    ss := TStringStream.Create(Dados);
    try
      TImage(FImage).Bitmap.LoadFromStream(ss);
    finally
      FreeAndNil(ss);
    end;
  end;
end;

destructor TItemLista.Destroy;
begin
  TMonitor.Enter(ListaPendenteDownload);
  try
    for var I := Pred(ListaPendenteDownload.Count) downto 0 do
      if ListaPendenteDownload[I].ID = FAtual.ID then
        ListaPendenteDownload.Delete(I);
  finally
    TMonitor.Exit(ListaPendenteDownload);
  end;

  inherited;
end;

end.

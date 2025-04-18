// Eduardo - 10/11/2024
unit Pipa.Explorador.Grade;

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
  FMX.Layouts,
  FMX.Gestures,
  Pipa.Tipos,
  Pipa.API,
  Pipa.LotScroll,
  Pipa.Explorador.Grade.Item;

type
  TExploradorGrade = class(TFrame)
    txtVazia: TText;
    procedure FrameResized(Sender: TObject);
  private
    FExibindo: Boolean;
    FLots: TLotScroll;
    FItensPorLinha: Integer;
    FPipa: TPipa;
    FItens: TItens;
    FItemListaClick: TProc<TItem>;
    FItemListaSelecionar: TProc<TAcaoItemLista, TItem>;
    FMiniatura: TFunc<TItem, TBytes>;
    procedure FillPage(PageIndex: Integer; Page: TLayout);
    procedure Criar;
  public
    procedure Exibir(Pipa: TPipa; Itens: TItens; Miniatura: TFunc<TItem, TBytes>; const ItemListaClick: TProc<TItem>; const ItemListaSelecionar: TProc<TAcaoItemLista, TItem>);
  end;

implementation

uses
//  Androidapi.Log,
  System.StrUtils,
  System.Math;

const
  TAMANHO = 100;

{$R *.fmx}

procedure TExploradorGrade.FillPage(PageIndex: Integer; Page: TLayout);
var
  iInicio: Integer;
  I: Integer;
  Miniatura: TFunc<TItem, TBytes>;
begin
  iInicio := PageIndex * FItensPorLinha;

  for I := iInicio to Min(Pred(iInicio + (FItensPorLinha)), Pred(Length(FItens))) do
  begin
    if (FItens[I].Tipo = Arquivo) and MatchStr(FItens[I].extensao.ToLower, ['jpg', 'bmp', 'png']) then
      Miniatura := FMiniatura
    else
      Miniatura := nil;

    TItemLista.New(Page, TAMANHO, FItens[I], FPipa.Icone(FItens[I]), Miniatura, FItemListaClick, FItemListaSelecionar);
  end;
end;

procedure TExploradorGrade.Criar;
var
  iItensPorLinha: Integer;
  iScroll: Single;
begin
  iItensPorLinha := Floor(Self.Width / TAMANHO);

  iItensPorLinha := Max(1, iItensPorLinha);

//  LOGI(PAnsiChar(AnsiString('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>')));
//  LOGI(PAnsiChar(AnsiString('<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<')));

  if iItensPorLinha = FItensPorLinha then
    Exit;

  FItensPorLinha := iItensPorLinha;
  iScroll := 0;

  if Assigned(FLots) then
  begin
    iScroll := FLots.ScrollPosition;
    FLots.Free;
  end;

  FLots := TLotScroll.Create(Self, Ceil(Length(FItens) / FItensPorLinha), TAMANHO);
  FLots.Parent := Self;
  FLots.Align := TAlignLayout.Client;
  FLots.OnFillPage := FillPage;

  FLots.ScrollPosition := iScroll;
end;

procedure TExploradorGrade.Exibir(Pipa: TPipa; Itens: TItens; Miniatura: TFunc<TItem, TBytes>; const ItemListaClick: TProc<TItem>; const ItemListaSelecionar: TProc<TAcaoItemLista, TItem>);
begin
  FPipa := Pipa;
  FItens := Itens;
  FMiniatura := Miniatura;
  FItemListaClick := ItemListaClick;
  FItemListaSelecionar := ItemListaSelecionar;

  txtVazia.Visible := Length(FItens) = 0;

  FItensPorLinha := -1;

  Criar;

  FExibindo := True;
end;

procedure TExploradorGrade.FrameResized(Sender: TObject);
begin
  if FExibindo then
    Criar;
end;

end.

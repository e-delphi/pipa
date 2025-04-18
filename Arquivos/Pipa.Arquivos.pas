// Eduardo - 30/10/2024
unit Pipa.Arquivos;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Variants,
  System.Net.URLClient,
  System.Net.HttpClient,
  System.Net.HttpClientComponent,
  System.Generics.Collections,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  FMX.Graphics,
  FMX.Dialogs,
  FMX.Layouts,
  FMX.Objects,
  FMX.Controls.Presentation,
  FMX.MultiView,
  Pipa.Tipos,
  Pipa.API,
  Pipa.Explorador.Grade,
  Pipa.Explorador.Grade.Item, FMX.StdCtrls, FMX.Ani;

type
  TArquivos = class(TFrame)
    rtgTop: TRectangle;
    rtgAcaoEsquerda: TRectangle;
    pthOpcoes: TPath;
    pthVoltar: TPath;
    rctUsuario: TRectangle;
    txtPastaAtual: TText;
    rtgAcaoDireita: TRectangle;
    pthAdicionar: TPath;
    pthRemover: TPath;
    mvOpcoes: TMultiView;
    rtgAtualizar: TRectangle;
    txtAtualizar: TText;
    canAtualizar: TColorAnimation;
    procedure rtgAcaoEsquerdaClick(Sender: TObject);
    procedure rtgAcaoDireitaClick(Sender: TObject);
    procedure FrameKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char; Shift: TShiftState);
    procedure rtgAtualizarClick(Sender: TObject);
  private
    FPipa: TPipa;
    FSelecao: TArray<TItem>;
    Grade: TExploradorGrade;
    FNiveis: TArray<TPair<Integer, String>>;
    procedure SetSelecao(const Value: TArray<TItem>);
    property Selecao: TArray<TItem> read FSelecao write SetSelecao;
    procedure ItemListaClick(Item: TItem);
    procedure Listar(ID: Integer; sPasta: String; Itens: TItens);
    procedure ItemListaSelecionar(Acao: TAcaoItemLista; Item: TItem);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

implementation

uses
  System.JSON,
  System.NetEncoding,
  System.StrUtils,
  System.IOUtils,
  FMX.MultiResBitmap,
  Pipa.NovaPasta,
  Pipa.ConfirmarExclusao,
  Pipa.Visualizador,
  Pipa.Novo,
  Pipa.Selecao.Arquivo,
  FMX.VirtualKeyboard,
  FMX.Platform,
  System.Generics.Defaults;

{$R *.fmx}

constructor TArquivos.Create(AOwner: TComponent);
begin
  inherited;
  pthOpcoes.Visible := True;
  pthVoltar.Visible := False;

  Grade := TExploradorGrade.Create(Self);
  Grade.Align := TAlignLayout.Client;
  Grade.Parent := Self;

  FPipa := TPipa.Create;
  Listar(0, EmptyStr, FPipa.Listar);
end;

destructor TArquivos.Destroy;
begin
  FreeAndNil(FPipa);
  inherited;
end;

procedure TArquivos.FrameKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char; Shift: TShiftState);
var
  FService: IFMXVirtualKeyboardService;
begin
  if Key = vkHardwareBack then
  begin
    TPlatformServices.Current.SupportsPlatformService(IFMXVirtualKeyboardService, IInterface(FService));
    if (FService <> nil) and not (TVirtualKeyboardState.Visible in FService.VirtualKeyboardState) then
      rtgAcaoEsquerdaClick(rtgAcaoEsquerda);
  end;
end;

procedure TArquivos.Listar(ID: Integer; sPasta: String; Itens: TItens);
var
  I: Integer;
  bExiste: Boolean;
begin
  Selecao := [];

  bExiste := False;
  for I := Low(FNiveis) to High(FNiveis) do
  begin
    if FNiveis[I].Key = ID then
    begin
      bExiste := True;
      Break;
    end;
  end;
  if not bExiste then
    FNiveis := FNiveis + [TPair<Integer, String>.Create(ID, sPasta)];

  txtPastaAtual.Text := sPasta;
  pthOpcoes.Visible := sPasta.IsEmpty;
  pthVoltar.Visible := not sPasta.IsEmpty;

  Grade.Exibir(FPipa, Itens, FPipa.Miniatura, ItemListaClick, ItemListaSelecionar);
end;

procedure TArquivos.ItemListaClick(Item: TItem);
var
  Visualizador: TVisualizador;
begin
  case Item.Tipo of
    TTipoItem.Pasta: Listar(Item.id, Item.nome, FPipa.Listar(Item.id));
    TTipoItem.Arquivo:
    begin
      Visualizador := TVisualizador.Create(Self);
      try
        Visualizador.Parent := Self;
        Visualizador.Align := TAlignLayout.Contents;

        Visualizador.Exibir(Item.nome +'.'+ Item.extensao, FPipa.Receber(Item.id));
      except
        FreeAndNil(Visualizador);
        raise;
      end;
    end;
  end;
end;

procedure TArquivos.ItemListaSelecionar(Acao: TAcaoItemLista; Item: TItem);
begin
//  case Acao of
//    Marcar: Selecao := Selecao + [Item];
//    Desmarcar:
//    begin
//      for var I := Low(Selecao) to High(Selecao) do
//      begin
//        if (Selecao[I].Tipo = Item.Tipo) and (Selecao[I].Pasta.ToString = Item.Pasta.ToString) and (Selecao[I].Nome = Item.Nome) then
//        begin
//          var Temp := Selecao;
//          Delete(Temp, I, 1);
//          Selecao := Temp;
//          Break;
//        end;
//      end;
//    end;
//  end;
end;

procedure TArquivos.SetSelecao(const Value: TArray<TItem>);
begin
  FSelecao := Value;
  pthAdicionar.Visible := Length(FSelecao) = 0;
  pthRemover.Visible   := Length(FSelecao) <> 0;
end;

procedure TArquivos.rtgAcaoEsquerdaClick(Sender: TObject);
begin
  if Length(FNiveis) = 1 then
  begin
    mvOpcoes.ShowMaster;
  end
  else
  begin
    Delete(FNiveis, Pred(Length(FNiveis)), 1);
    Listar(FNiveis[Pred(Length(FNiveis))].Key, FNiveis[Pred(Length(FNiveis))].Value, FPipa.Listar(FNiveis[Pred(Length(FNiveis))].Key));
  end;
end;

procedure TArquivos.rtgAtualizarClick(Sender: TObject);
begin
  FPipa.Atualizar;
end;

procedure TArquivos.rtgAcaoDireitaClick(Sender: TObject);
//var
//  Novo: TNovo;
//  ConfirmarExclusao: TConfirmarExclusao;
//  SelecaoArquivo: TSelecaoArquivo;
begin
//  if Length(Selecao) = 0 then
//  begin
//    Novo := TNovo.Create(Self);
//    Novo.Parent := Self;
//    Novo.Align := TAlignLayout.Contents;
//
//    Novo.Arquivo :=
//      procedure
//      begin
//        SelecaoArquivo := TSelecaoArquivo.Create(Self);
//        SelecaoArquivo.Parent := Self;
//        SelecaoArquivo.Align := TAlignLayout.Contents;
//        SelecaoArquivo.Selecionar :=
//          procedure(aArquivo: TArray<String>)
//          begin
//            for var Item in aArquivo do
//              FPipa.Enviar(Item, txtPastaAtual.Text);
//            Listar(txtPastaAtual.Text, FPipa.Listar(txtPastaAtual.Text));
//          end;
//      end;
//
//    Novo.Pasta :=
//      procedure
//      var
//        NovaPasta: TNovaPasta;
//      begin
//        NovaPasta := TNovaPasta.Create(Self);
//        try
//          NovaPasta.Parent := Self;
//          NovaPasta.Align := TAlignLayout.Contents;
//
//          NovaPasta.Criar :=
//            procedure(sNome: String)
//            begin
//              FPipa.NovaPasta(txtPastaAtual.Text, sNome);
//              Listar(txtPastaAtual.Text, FPipa.Listar(txtPastaAtual.Text));
//            end;
//
//          NovaPasta.edtNome.Text := 'Pasta sem nome';
//          NovaPasta.edtNome.SetFocus;
//        except
//          FreeAndNil(NovaPasta);
//          raise;
//        end;
//      end;
//  end
//  else
//  begin
//    ConfirmarExclusao := TConfirmarExclusao.Create(Self);
//    try
//      ConfirmarExclusao.Parent := Self;
//      ConfirmarExclusao.Align := TAlignLayout.Contents;
//
//      if Length(Selecao) > 1 then
//        ConfirmarExclusao.txtDescricao.Text := Length(Selecao).ToString +' itens'
//      else
//        ConfirmarExclusao.txtDescricao.Text := Selecao[0].Nome;
//
//      ConfirmarExclusao.Cancelar :=
//        procedure
//        begin
//          Listar(txtPastaAtual.Text, FPipa.Listar(txtPastaAtual.Text));
//        end;
//
//      ConfirmarExclusao.Excluir :=
//        procedure
//        begin
//          for var Selecionado in Selecao do
//          begin
//            if Selecionado.Tipo = TTipoItem.Pasta then
//              FPipa.ExcluirPasta(Selecionado.Pasta.Combine(Selecionado.Nome).ToString)
//            else
//              FPipa.ExcluirArquivo(Selecionado.Pasta.ToString, Selecionado.Nome);
//          end;
//
//          Listar(txtPastaAtual.Text, FPipa.Listar(txtPastaAtual.Text));
//
//        end;
//    except
//      FreeAndNil(ConfirmarExclusao);
//      raise;
//    end;
//  end;
end;

end.

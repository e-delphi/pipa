// Eduardo - 30/10/2024
unit Pipa.Arquivos;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Variants,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  FMX.Graphics,
  FMX.Dialogs,
  FMX.Layouts,
  FMX.Objects,
  FMX.Controls.Presentation,
  FMX.MultiView,
  FMX.TabControl,
  System.Net.URLClient,
  System.Net.HttpClient,
  System.Net.HttpClientComponent,
  Pipa.Tipos,
  Pipa.API,
  Pipa.Explorador.Grade,
  Pipa.Explorador.Grade.Item;

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
    odDialog: TOpenDialog;
    procedure rtgAcaoEsquerdaClick(Sender: TObject);
    procedure rtgAcaoDireitaClick(Sender: TObject);
    procedure FrameKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char; Shift: TShiftState);
  private
    FPipa: TPipa;
    FSelecao: TArray<TItem>;
    Grade: TExploradorGrade;
    procedure SetSelecao(const Value: TArray<TItem>);
    property Selecao: TArray<TItem> read FSelecao write SetSelecao;
    procedure ItemListaClick(Item: TItem);
    procedure Listar(sPasta: String; Itens: TItens);
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
  FMX.VirtualKeyboard,
  FMX.Platform,
  System.Generics.Collections,
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
  Listar(EmptyStr, FPipa.Listar);
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

procedure TArquivos.Listar(sPasta: String; Itens: TItens);
begin
  Selecao := [];

  txtPastaAtual.Text := sPasta;
  pthOpcoes.Visible := sPasta.IsEmpty;
  pthVoltar.Visible := not sPasta.IsEmpty;

  Grade.Exibir(FPipa, Itens, FPipa.Miniatura, ItemListaClick, ItemListaSelecionar)
end;

procedure TArquivos.ItemListaClick(Item: TItem);
var
  Visualizador: TVisualizador;
begin
  case Item.Tipo of
    TTipoItem.Pasta: Listar(Item.Pasta.Combine(Item.Nome).ToString, FPipa.Listar(Item.Pasta.Combine(Item.Nome).ToString));
    TTipoItem.Arquivo:
    begin
      Visualizador := TVisualizador.Create(Self);
      try
        Visualizador.Parent := Self;
        Visualizador.Align := TAlignLayout.Contents;

        Visualizador.Exibir(Item.Nome, FPipa.Receber(Item.Pasta.ToString, Item.Nome));
      except
        FreeAndNil(Visualizador);
        raise;
      end;
    end;
  end;
end;

procedure TArquivos.ItemListaSelecionar(Acao: TAcaoItemLista; Item: TItem);
begin
  case Acao of
    Marcar: Selecao := Selecao + [Item];
    Desmarcar:
    begin
      for var I := Low(Selecao) to High(Selecao) do
      begin
        if (Selecao[I].Tipo = Item.Tipo) and (Selecao[I].Pasta.ToString = Item.Pasta.ToString) and (Selecao[I].Nome = Item.Nome) then
        begin
          var Temp := Selecao;
          Delete(Temp, I, 1);
          Selecao := Temp;
          Break;
        end;
      end;
    end;
  end;
end;

procedure TArquivos.SetSelecao(const Value: TArray<TItem>);
begin
  FSelecao := Value;
  pthAdicionar.Visible := Length(FSelecao) = 0;
  pthRemover.Visible   := Length(FSelecao) <> 0;
end;

procedure TArquivos.rtgAcaoEsquerdaClick(Sender: TObject);
var
  Pasta: TPasta;
begin
  Pasta := txtPastaAtual.Text.Split([TPath.DirectorySeparatorChar]);
  Pasta := Pasta.Parent;
  Listar(Pasta.ToString, FPipa.Listar(Pasta.ToString));
end;

procedure TArquivos.rtgAcaoDireitaClick(Sender: TObject);
var
  Novo: TNovo;
  ConfirmarExclusao: TConfirmarExclusao;
begin
  if Length(Selecao) = 0 then
  begin
    Novo := TNovo.Create(Self);
    Novo.Parent := Self;
    Novo.Align := TAlignLayout.Contents;

    Novo.Arquivo :=
      procedure
      begin
        if not odDialog.Execute then
          Exit;

        FPipa.Enviar(odDialog.FileName, txtPastaAtual.Text);
        Listar(txtPastaAtual.Text, FPipa.Listar(txtPastaAtual.Text));
      end;

    Novo.Pasta :=
      procedure
      var
        NovaPasta: TNovaPasta;
      begin
        NovaPasta := TNovaPasta.Create(Self);
        try
          NovaPasta.Parent := Self;
          NovaPasta.Align := TAlignLayout.Contents;

          NovaPasta.Criar :=
            procedure(sNome: String)
            begin
              FPipa.NovaPasta(txtPastaAtual.Text, sNome);
              Listar(txtPastaAtual.Text, FPipa.Listar(txtPastaAtual.Text));
            end;

          NovaPasta.edtNome.Text := 'Pasta sem nome';
          NovaPasta.edtNome.SetFocus;
        except
          FreeAndNil(NovaPasta);
          raise;
        end;
      end;
  end
  else
  begin
    ConfirmarExclusao := TConfirmarExclusao.Create(Self);
    try
      ConfirmarExclusao.Parent := Self;
      ConfirmarExclusao.Align := TAlignLayout.Contents;

      if Length(Selecao) > 1 then
        ConfirmarExclusao.txtDescricao.Text := Length(Selecao).ToString +' itens'
      else
        ConfirmarExclusao.txtDescricao.Text := Selecao[0].Nome;

      ConfirmarExclusao.Cancelar :=
        procedure
        begin
          Listar(txtPastaAtual.Text, FPipa.Listar(txtPastaAtual.Text));
        end;

      ConfirmarExclusao.Excluir :=
        procedure
        begin
          for var Selecionado in Selecao do
          begin
            if Selecionado.Tipo = TTipoItem.Pasta then
              FPipa.ExcluirPasta(Selecionado.Pasta.Combine(Selecionado.Nome).ToString)
            else
              FPipa.ExcluirArquivo(Selecionado.Pasta.ToString, Selecionado.Nome);
          end;

          Listar(txtPastaAtual.Text, FPipa.Listar(txtPastaAtual.Text));

        end;
    except
      FreeAndNil(ConfirmarExclusao);
      raise;
    end;
  end;
end;

end.

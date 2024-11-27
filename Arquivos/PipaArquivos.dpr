program PipaArquivos;

uses
  System.StartUpCopy,
  FMX.Forms,
  FMX.Skia,
  Pipa.Tipos in 'Pipa.Tipos.pas',
  Pipa.API in 'Pipa.API.pas',
  REST.API in 'REST.API.pas',
  Pipa.Ordenacao in 'Pipa.Ordenacao.pas',
  Pipa.Inicio in 'Pipa.Inicio.pas' {Inicio: TInicio},
  Pipa.Arquivos in 'Pipa.Arquivos.pas' {Arquivos: TFrame},
  Pipa.Explorador.Grade in 'Pipa.Explorador.Grade.pas' {ExploradorGrade: TFrame},
  Pipa.Explorador.Grade.Item in 'Pipa.Explorador.Grade.Item.pas' {ItemLista: TFrame},
  Pipa.Visualizador in 'Pipa.Visualizador.pas' {Visualizador: TFrame},
  Pipa.Visualizador.Imagem in 'Pipa.Visualizador.Imagem.pas' {ImageViewerFrame: TFrame},
  Pipa.NovaPasta in 'Pipa.NovaPasta.pas' {NovaPasta: TFrame},
  Pipa.ConfirmarExclusao in 'Pipa.ConfirmarExclusao.pas' {ConfirmarExclusao: TFrame},
  Pipa.LotScroll in 'Pipa.LotScroll.pas',
  Pipa.Miniatura in 'Pipa.Miniatura.pas',
  Pipa.Logo in 'Pipa.Logo.pas' {Logo: TFrame},
  Pipa.Novo in 'Pipa.Novo.pas' {Novo: TFrame};

{$R *.res}

begin
  GlobalUseSkia := True;
  ReportMemoryLeaksOnShutdown := True;

  Application.Initialize;
  Application.CreateForm(TInicio, Inicio);
  Application.Run;
end.

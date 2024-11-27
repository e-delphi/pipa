// Eduardo - 23/11/2024
unit Pipa.Migracoes;

interface

uses
  Pipa.Constantes;

const
  SQL =
    sl +'pragma foreign_keys = on; '+
    sl +
    sl +'create table if not exists pasta( '+
    sl +'    id integer primary key autoincrement, '+
    sl +'    pasta_id integer null,   '+
    sl +'    nome text not null, '+
    sl +'    foreign key (pasta_id) references pasta(id), '+
    sl +'    unique (pasta_id, nome) '+
    sl +'); '+
    sl +
    sl +'create table if not exists arquivo( '+
    sl +'    id integer primary key autoincrement, '+
    sl +'    pasta_id integer null, '+
    sl +'    nome text not null,     '+
    sl +'    extensao text null, '+
    sl +'    tamanho integer not null, '+
    sl +'    criado text null, '+
    sl +'    modificado text null, '+
    sl +'    foreign key (pasta_id) references pasta(id), '+
    sl +'    unique (pasta_id, nome, extensao) '+
    sl +'); '+
    sl +
    sl +'create table if not exists foto( '+
    sl +'    id integer primary key autoincrement, '+
    sl +'    arquivo_id integer, '+
    sl +'    tirada text null, '+
    sl +'    camera text null, '+
    sl +'    f real null, '+
    sl +'    exposicao real null, '+
    sl +'    distancia_focal real null, '+
    sl +'    iso integer null,  '+
    sl +'    megapixels integer null, '+
    sl +'    largura integer not null, '+
    sl +'    altura integer not null, '+
    sl +'    coordenadas text null, '+
    sl +'    altitude real null, '+
    sl +'    flash integer, '+
    sl +'    foreign key (arquivo_id) references arquivo(id), '+
    sl +'    unique (arquivo_id) '+
    sl +'); '+
    sl +
    sl +'create table if not exists miniatura( '+
    sl +'    id integer primary key autoincrement, '+
    sl +'    foto_id integer, '+
    sl +'    largura integer not null, '+
    sl +'    altura integer not null, '+
    sl +'    bytes blob,  '+
    sl +'    foreign key (foto_id) references foto(id), '+
    sl +'    unique (foto_id, largura, altura) '+
    sl +'); '+
    sl +
    sl +'create table if not exists album( '+
    sl +'    id integer primary key autoincrement, '+
    sl +'    nome text not null, '+
    sl +'    unique (nome) '+
    sl +'); '+
    sl +
    sl +'create table if not exists album_foto( '+
    sl +'    id integer primary key autoincrement, '+
    sl +'    album_id integer not null, '+
    sl +'    foto_id integer not null, '+
    sl +'    foreign key (album_id) references album(id), '+
    sl +'    foreign key (foto_id) references foto(id), '+
    sl +'    unique (album_id, foto_id) '+
    sl +'); '+
    sl +
    sl +'create table if not exists classificacao( '+
    sl +'    id integer primary key autoincrement, '+
    sl +'    descricao text not null, '+
    sl +'    unique (descricao) '+
    sl +'); '+
    sl +
    sl +'create table if not exists classificacao_foto( '+
    sl +'    id integer primary key autoincrement, '+
    sl +'    foto_id integer not null, '+
    sl +'    classificacao_id integer not null, '+
    sl +'    foreign key (foto_id) references foto(id), '+
    sl +'    foreign key (classificacao_id) references classificacao(id), '+
    sl +'    unique (foto_id, classificacao_id) '+
    sl +'); ';

implementation

end.

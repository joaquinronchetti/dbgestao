-- trabalho de banco de dados - sistema de tarefas
-- criacao das tabelas do sistema

create table colaboradores (
    id_colaborador serial primary key,
    nome varchar(100) not null,
    email varchar(100) not null unique,
    senha varchar(50) not null,
    ativo boolean not null default true
);

create table categorias (
    id_categoria serial primary key,
    nome varchar(50) not null unique,
    descricao varchar(200)
);

create table tarefas (
    id_tarefa serial primary key,
    titulo varchar(150) not null,
    descricao text,
    data_criacao timestamp not null default current_timestamp,
    prazo_entrega date not null,
    status varchar(20) not null default 'pendente',
    id_colaborador int not null,
    id_categoria int not null,
    
    foreign key (id_colaborador) references colaboradores(id_colaborador),
    foreign key (id_categoria) references categorias(id_categoria),
    check (status in ('pendente', 'em andamento', 'concluida'))
);

create table historico_tarefas (
    id_historico serial primary key,
    id_tarefa int not null,
    acao varchar(255) not null,
    data_registro timestamp not null default current_timestamp,
    
    foreign key (id_tarefa) references tarefas(id_tarefa) on delete cascade
);


-- triggers e functions

-- verifica se o usuario ta ativo antes de cadastrar a tarefa
create or replace function verifica_colaborador_ativo()
returns trigger as $$
declare
    esta_ativo boolean;
begin
    select ativo into esta_ativo 
    from colaboradores 
    where id_colaborador = new.id_colaborador;

    if esta_ativo is null or esta_ativo = false then
        raise exception 'erro: nao pode colocar tarefa para colaborador inativo ou que nao existe!';
    end if;

    new.data_criacao := current_timestamp;
    return new;
end;
$$ language plpgsql;

create trigger trg_checa_colaborador
before insert on tarefas
for each row
execute function verifica_colaborador_ativo();


-- salva no historico toda vez que cria uma tarefa nova
create or replace function salva_historico_criacao()
returns trigger as $$
begin
    insert into historico_tarefas (id_tarefa, acao, data_registro)
    values (new.id_tarefa, 'tarefa cadastrada como: ' || new.status, current_timestamp);
    
    return new;
end;
$$ language plpgsql;

create trigger trg_gera_historico
after insert on tarefas
for each row
execute function salva_historico_criacao();


-- funcao para pesquisar colaborador pelo nome ou email
create or replace function buscar_colaborador(texto varchar)
returns table (
    id int,
    nome_colab varchar,
    email_colab varchar,
    ativo_colab boolean
) as $$
begin
    return query
    select 
        id_colaborador, 
        nome, 
        email, 
        ativo
    from colaboradores
    where nome ilike '%' || texto || '%' 
       or email ilike '%' || texto || '%';
end;
$$ language plpgsql;


-- inserindo dados para teste

-- colaboradores (o ultimo ta false para testar se a trigger bloqueia)
insert into colaboradores (nome, email, senha, ativo) values
('lucas ferreira', 'lucas.ferreira@techschool.com.br', 'lucas2026', true),
('beatriz oliveira', 'bia.oliveira@techschool.com.br', 'bia@1234', true),
('gabriel souza', 'gabriel.souza@techschool.com.br', 'gabi_dev', true),
('fernanda lima', 'fernanda.lima@techschool.com.br', 'fer9876', false);

-- categorias
insert into categorias (nome, descricao) values
('front-end', 'telas, html, css e ajustes visuais do sistema'),
('back-end', 'logica do servidor, rotas e conexao com o banco'),
('suporte e testes', 'testar bugs e ajudar os usuarios');

-- tarefas (isso aqui ja vai disparar as triggers e preencher o historico)
insert into tarefas (titulo, descricao, prazo_entrega, status, id_colaborador, id_categoria) values
('criar tela de login', 'fazer o formulario de entrada com validacao de campos', '2026-11-18', 'concluida', 1, 1),
('conectar api com postgresql', 'configurar o arquivo de conexao e testar o select', '2026-11-22', 'em andamento', 2, 2),
('testar cadastro de tarefas', 'ver se o sistema barra usuario inativo', '2026-11-26', 'pendente', 3, 3),
('arrumar menu responsivo', 'o botao do menu ta quebrando no celular', '2026-11-29', 'pendente', 1, 1);


-- views para consulta

-- mostra tudo junto na tela inicial
create or replace view vw_lista_geral as
select 
    c.nome as colaborador,
    t.titulo as tarefa,
    cat.nome as categoria,
    t.prazo_entrega,
    t.status
from tarefas t
join colaboradores c on t.id_colaborador = c.id_colaborador
join categorias cat on t.id_categoria = cat.id_categoria;

-- mostra as tarefas mais urgentes primeiro e quantos dias faltam
create or replace view vw_prazos_tarefas as
select 
    t.titulo as tarefa,
    t.prazo_entrega,
    (t.prazo_entrega - current_date) as dias_que_faltam,
    t.status,
    c.nome as responsavel
from tarefas t
join colaboradores c on t.id_colaborador = c.id_colaborador
order by t.prazo_entrega asc;

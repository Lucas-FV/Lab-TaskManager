## 1. Implementações Realizadas
* **Data de Vencimento:** Adicionado campo `dueDate` ao `Task`, implementado `DatePicker` no formulário e lógica de ordenação na lista principal.
* **Alerta Visual:** Cards de tarefas vencidas (`isOverdue`) ganham destaque com borda vermelha e texto de aviso.
* **Sistema de Categorias:** Criado modelo e tabela `Category` (com cores).
* **Relação de Dados:** `Task` agora possui um `categoryId` para relacionar com `Category`.
* **Filtro de Categoria:** Adicionado `DropdownButtonFormField` ao formulário (populado pelo DB) e um `PopupMenuButton` na `AppBar` para filtrar a lista de tarefas.
* **UI Dinâmica:** Borda do `TaskCard` agora usa a cor da Categoria associada.

## 2. Desafios Encontrados
* **Desafio:** Gerenciamento da migração do banco de dados `sqflite` (`v1` -> `v2` -> `v3`). Erros de `duplicate column` e `no column named` ocorreram quando o schema e o modelo ficavam dessincronizados.
* **Solução:** Durante o desenvolvimento, a solução mais rápida foi **desinstalar o app do emulador** para forçar o `onCreate` do banco com o schema mais recente.

## 3. Melhorias Implementadas
* **UI Rica:** O `TaskCard` foi atualizado para exibir *ambos* os "chips" de **Categoria** e **Prioridade** (usando um `Wrap`), em vez de substituir um pelo outro.
* **Feedback de Filtro:** O ícone de filtro de Categoria na `AppBar` muda de cor quando um filtro está ativo.

## 4. Aprendizados
* **`sqflite`:** Versionamento e migração de schema (`onCreate` vs. `onUpgrade` com `ALTER TABLE`).
* **Relações de DB:** Implementação de chave estrangeira (`categoryId`) para relacionar tabelas.
* **Async/Estado:** Uso de `Future.wait` para carregar dados de múltiplas tabelas (tarefas e categorias) simultaneamente.
* **Layout:** Uso do widget `Wrap` para criar layouts de "chips" responsivos.

## 5. Próximos Passos
* Implementar o **Exercício 3 (Notificações)** com lembretes agendados.
* Criar um **CRUD de Categorias** (permitir ao usuário criar/editar/deletar suas próprias categorias).
* Adicionar **gráficos de estatísticas** na tela inicial.

## VIDEOS DEMONSTRAÇÃO

### LAB UX e UI MELHORADA
https://youtu.be/vw7oKdRmE7k

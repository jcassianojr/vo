Aqui esta o arquivo `blprinter.md` estruturado para documentacao tecnica no padrao GitHub, consolidando as informacoes sobre implementacao e referencia da classe `BL_Printer`.

---

# BL_Printer Documentation

A **BL_Printer** e uma classe para Visual Objects (VO 2.7a) voltada para impressao com visualizacao de pagina integrada, utilizando *Enhanced Metafiles* para proporcionar uma experiencia de visualizacao de alta qualidade.

## 1. Guia de Implementacao

Para integrar o `BL_Printer` em uma janela (ex: `StandardShellWindow` ou `SubclassForm`), siga estes passos:

### Estrutura da Classe

Declare os objetos necessarios na sua classe de controle:

```xbase
CLASS JIMPEDI INHERIT _JIMPEDI
    PROTECT oPrinter      AS BL_Printer
    PROTECT oMenuVorschau AS BL_PrinterMenu
    PROTECT oPrinterRTF   AS BL_Printer
    PROTECT cFileRTF      AS STRING
    EXPORT oOwner

```

### Inicializacao (Init)

O metodo `INIT` deve chamar o `SUPER:INIT` antes de qualquer outra operacao e inicializar os objetos de impressao **antes** de chamar metodos como `SHOW()`.

```xbase
METHOD INIT(oOwner) CLASS JIMPEDI
    SUPER:INIT(oOwner)
    
    // Configuracao da Impressora
    oPrinter := BL_Printer{SELF, "Druck mit BL_Printer", , FALSE}
    oPrinter:PrintingDevice:Orientation := DMORIENT_LANDSCAPE // 2
    
    // Configuracao de RTF (se aplicavel)
    oPrinterRTF := BL_Printer{SELF, "Druck mit BL_Printer", , FALSE}
    oPrinterRTF:PrintingDevice:Orientation := DMORIENT_PORTRAIT // 1
    cFileRTF := ""
    
    SELF:SHOW()

```

---

## 2. Caracteristicas Principais

* 
**Renderizacao**: As paginas sao criadas como *Enhanced Metafiles*.


* 
**Precisao**: Padrao de medidas em centesimos de milimetro. A qualidade da saida depende da resolucao do driver da impressora.


* 
**Margens**: Nao sao consideradas nas especificacoes de posicao, sendo aplicadas apenas no momento da impressao ou visualizacao. **Nota**: Devem ser definidas antes da criacao das paginas.


* 
**Navegacao**: Suporte a zoom e navegacao entre multiplas paginas.


* **Flexibilidade**:
* E possivel passar menus, titulos e estilos de mouse personalizados na chamada da visualizacao.


* 
`BL_Printer:ClipPage := FALSE`: Remove a limitacao da area de impressao para a saida do metafile.


* 
`BL_Printer:ExtraPrintOffsets`: Ajusta deslocamentos de impressao (util para drivers com comportamento incorreto).





---

## 3. Metodos e Callbacks

* 
**`BL_PrinterPageChanged(oBL_PrinterPageEvent)`**: Metodo de callback disparado ao navegar entre paginas na visualizacao.


* **`BL_PrinterCreatePage(nPage)`**: Chamado quando uma pagina solicitada nao existe (NULL_PTR). Permite a criacao dinamica de paginas, ideal para grandes conjuntos de dados.


* 
**Impressao de Texto**: Utiliza `Write()` em conjunto com `NewLine()`.


* Fonte padrao: "Courier New", 12, negrito.


* Para fontes customizadas, utilize `BL_CreateFontHmm()` para alinhar as unidades de medida do *Device-Context*.





---

## 4. Modulos do Projeto

| Modulo | Descricao |
| --- | --- |
| `BL_Printer` | Classe principal de controle de impressao 

 |
| `BL_PreviewDta` | DataWindow para visualizacao da pagina 

 |
| `BL_PreviewMenu` | Menu de controle para o Preview 

 |
| `BL_PrintInfoDlg` | Dialogo de status com opcao de cancelamento 

 |
| `BL_Func` | Funcoes auxiliares 

 |
| `BL_Resourcen` | Recursos visuais (Cursors) 

 |

---

Nota: Para casos de uso especificos (como `PreviewTXT`), certifique-se de exportar corretamente os arquivos MEF e instanciar a classe correspondente ao contexto de uso (`EMUSO`).
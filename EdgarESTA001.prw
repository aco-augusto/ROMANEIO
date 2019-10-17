#Include 'Protheus.ch'
#Include 'FWMVCDef.ch'

/*/{Protheus.doc} ESTM001
	Rotina MVC para manutenção, separação e conferência de romaneio
	@uso EST - Estoque e Custo
	@author ACO - Brasoft
	@since 11/10/2019
	@version V 0.1 - 12.1.25
/*/
User Function ESTA001()

	Private oBrowse 	:= FwMBrowse():New()				//Variavel de Browse

	chkfile("ZZ2")
	chkfile("ZZ1")

	// aMenu := MenuDef()

	//Alias do Browse
	oBrowse:SetAlias("ZZ1")

	//Descrição da Parte Superior Esquerda do Browse
	oBrowse:SetDescripton("Romaneio de Separação")

	//Legenda: Código da Fase (10=Solicitação; 20=Separação, 30=Separado, 40=Finalizado)
	oBrowse:AddLegend( "Empty(ZZ1->ZZ1_FASE) .OR. ZZ1->ZZ1_FASE == '10'"  ,"GREEN", "Aguardando separação")
	oBrowse:AddLegend( "ZZ1->ZZ1_FASE == '20'"   						  ,"GRAY" , "Em separação")
	oBrowse:AddLegend( "ZZ1->ZZ1_FASE == '25'"   						  ,"BLUE" , "Separação finalizada")
	oBrowse:AddLegend( "ZZ1->ZZ1_FASE == '30'"   						  ,"PINK" , "Em conferência")
	oBrowse:AddLegend( "ZZ1->ZZ1_FASE == '35'"   						  ,"PINK" , "Em conferência")
	oBrowse:AddLegend( "ZZ1->ZZ1_FASE == '40'"   						  ,"RED"  , "Doc. fiscal gerado")
	oBrowse:SetMenuDef( 'EdgarESTA001' )
	//Habilita os Botões Ambiente e WalkThru
	oBrowse:SetAmbiente(.F.)
	oBrowse:SetWalkThru(.F.)

	//Desabilita os Detalhes da parte inferior do Browse
	oBrowse:DisableDetails()

	//Ativa o Browse
	oBrowse:Activate()


Return

/*/{Protheus.doc} MenuDef
	Rotina para criação de lista de opção (MENU)
	@uso EST - Estoque e Custo
	@author ACO - Brasoft
	@since 11/10/2019
/*/
Static Function MenuDef()

	Local aMenu :=	{}

	ADD OPTION aMenu TITLE 'Pesquisar'       		ACTION 'VIEWDEF.EdgarESTA001'		OPERATION 1 ACCESS 0
	ADD OPTION aMenu TITLE 'Visualizar'      		ACTION 'VIEWDEF.EdgarESTA001'		OPERATION 2 ACCESS 0
	ADD OPTION aMenu TITLE 'Incluir'         		ACTION 'VIEWDEF.EdgarESTA001' 		OPERATION 3 ACCESS 0
	ADD OPTION aMenu TITLE 'Alterar'         		ACTION 'VIEWDEF.EdgarESTA001' 		OPERATION 4 ACCESS 0
	ADD OPTION aMenu TITLE 'Realizar Separação'  	ACTION 'U_ESTROMAN("SEPARAR")'		OPERATION 2 ACCESS 0
	ADD OPTION aMenu TITLE 'Estornar Separação' 	ACTION 'U_ESTROMANr("ESTORNAR")' 	OPERATION 2 ACCESS 0
	ADD OPTION aMenu TITLE 'Conferir Romaneio' 		ACTION 'U_ESTROMAN("CONFERIR")'		OPERATION 2 ACCESS 0
	ADD OPTION aMenu TITLE 'Legenda' 				ACTION 'U_ESTROMAN("LEGENDA")'		OPERATION 2 ACCESS 0
	ADD OPTION aMenu TITLE 'Excluir'         		ACTION 'U_ESTROMAN("EXCLUIR")'		OPERATION 5 ACCESS 0
	ADD OPTION aMenu TITLE 'Relatório Coleta'		ACTION 'U_ESTROMAN("RELATO")'		OPERATION 8 ACCESS 0

Return(aMenu)

/*/{Protheus.doc} ESTROMAN
	Rotina para realização de chamadas de procedimentos 
	@uso EST - Estoque e Custo
	@author ACO - Brasoft
	@since 11/10/2019
/*/
USER FUNCTION ESTROMAN(cOperacao)

	IF 	   cOperacao == "SEPARAR"
	ELSEIF cOperacao == "ESTORNAR"
	ELSEIF cOperacao == "CONFERIR"
	ELSEIF cOperacao == "LEGENDA"
		u_E001Legenda()
	ELSEIF cOperacao == "EXCLUIR"
	ELSEIF cOperacao == "RELATO"
	ENDIF

RETURN

/*/{Protheus.doc} ModelDef
	Funcao de Modelo de Dados. Onde é definido a estrutura de dados
	@uso EST - Estoque e Custo
	@author ACO - Brasoft
	@since 11/10/2019
/*/
Static Function ModelDef()

	Local oStruZZ1  :=  FWFormStruct(1,'ZZ1') //Retorna a Estrutura do Alias passado como Parametro (1=Model,2=View)
	Local oStruZZ2	:=	FWFormStruct(1,'ZZ2') //FWFormStruct(1,'ZZ2', { |cCampo| VerCampo(cCampo) } )         
	Local oModel

	// oStruZZ1:RemoveField( "ZZ1_FILIAL" )

	//Instancia do Objeto de Modelo de Dados
	//oModel	:=	MpFormModel():New('MODELRATE01',/*Pre-Validacao*/,{ |oModel| VALIDCOMIT(oModel)},/*Commit*/,/*Commit*/,/*Cancel*/) 
	oModel := MpFormModel():New( "EdgarESTA001", /*Pre-Validacao*/,  /*Pos-Validacao*/, /*Commit*/, /*Cancel*/)

	//Adiciona um modelo de Formulario de Cadastro Similar à Enchoice ou Msmget
	oModel:AddFields('ZZ1CABEC', /*cOwner*/, oStruZZ1, /*bPreValidacao*/, /*bPosValidacao*/, /*bCarga*/ )

	//Adiciona um Modelo de Grid somilar à MsNewGetDados, BrGetDb
	oModel:AddGrid('ZZ2GRID', 'ZZ1CABEC', oStruZZ2,  /*bLinePre*/, /*bLinePost*/, /*bPreVal*/, /*bPosVal*/, /*BLoad*/ )


	// Faz relaciomaneto entre os compomentes do model
	oModel:SetRelation( 'ZZ2GRID', { { 'ZZ2_FILIAL', 'xFilial("ZZ2")' }, { 'ZZ2_ROMAN', 'ZZ1_ROMAN' }, { 'ZZ2_SEQROM', 'ZZ1_SEQROM' } }, ZZ2->(IndexKey(1)))

	oModel:SetPrimaryKey( { "ZZ1_FILIAL", "ZZ1_ROMAN", "ZZ1_SEQROM" } )

	// Indica que é opcional ter dados informados na Grid
	oModel:GetModel( 'ZZ2GRID' ):SetOptional(.F.)

	// Indica que o detalhe será somente visualizado.
	oModel:GetModel( 'ZZ2GRID' ):SetOnlyView(.T.)

	//Adiciona Descricao do Modelo de Dados
	oModel:SetDescription( 'Romaneio de Separação' )

	//Adiciona Descricao dos Componentes do Modelo de Dados
	oModel:GetModel( 'ZZ1CABEC' ):SetDescription( 'Dados do Romaneio' )
	oModel:GetModel( 'ZZ2GRID' ):SetDescription( 'Itens do Romaneio' )

Return(oModel)

/*/{Protheus.doc} ViewDef
	Funcao de Visualizacao. Onde é definido a visualizacao da Regra de Negocio. 
	@uso EST - Estoque e Custo
	@author ACO - Brasoft
	@since 11/10/2019
/*/
Static Function ViewDef()

Local oStruZZ1	:=	FWFormStruct(2,'ZZ1')
Local oStruZZ2	:=	FWFormStruct(2,'ZZ2')
Local oModel	:=	FwLoadModel('EdgarESTA001')	//Retorna o Objeto do Modelo de Dados
Local oView		:=	FwFormView():New()      //Instancia do Objeto de Visualização

oStruZZ1:RemoveField( "ZZ1_FILIAL" )

//Define o Modelo sobre qual a Visualizacao sera utilizada
oView:SetModel(oModel)

//Nao monta Abaas
//oStruZZ1:SetNoFolder()

//Vincula o Objeto visual de Cadastro com o modelo
oView:AddField( 'VIEW_ZZ1', oStruZZ1, 'ZZ1CABEC')

//Adiciona no nosso View um controle do tipo FormGrid(antiga newgetdados)
oView:AddGrid( 'VIEW_GRD_ZZ2', oStruZZ2, 'ZZ2GRID')

//Define o Preenchimento da Janela
oView:CreateHorizontalBox( 'ID_HBOX_40', 40 )
oView:CreateHorizontalBox( 'ID_HBOX_60', 60 )

// Relaciona o ID da View com o "box" para exibicao
oView:SetOwnerView( 'VIEW_ZZ1'  , 'ID_HBOX_40' )
oView:EnableTitleView('VIEW_ZZ1','Dados do Romaneio')

oView:SetOwnerView( 'VIEW_GRD_ZZ2', 'ID_HBOX_60' )
oView:EnableTitleView('VIEW_GRD_ZZ2','Itens do Romaneio')


// Criar novo botao na barra de botoes
//oView:AddUserButton( 'Calcular Valores', 'CLIPS', { |oView| Alert("botao teste") } )
// oView:AddUserButton( 'Separar por C.B.', 'CLIPS', { |oView| Aviso( "ATENÇÃO!", "Rotina em Desenvolvimento...", { "Ok" }) } )

// Define campos que terao Auto Incremento
//oView:AddIncrementField( 'VIEW_GRD_ZZ2', 'ZZ2_ITEM' ) 


Return oView

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³VALIDCOMITºAutor  ³Totvs TM            º Data ³  21/02/13   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Função para validaçao de do preenchimento do cabeçalho do   º±±
±±º          ³cadastro de cota capital.                                   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ GLT                                                        º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function VALIDCOMIT(oModel)
Local nOperation	:=	oModel:GetOperation()
//Local oModelGrid	:=	oModel:GetModel('ZZ2GRID')
//Local oModelCab		:=	oModel:GetModel('ZZ1CABEC')
Local lRetorno		:=	.T.
Local dDtIni		:= FwFldGet('ZZ1_DTINI')
Local dDtFim		:= FwFldGet('ZZ1_DTFIM')
Local nValor		:= FwFldGet('ZZ1_VLRLIT')
Local nValorRat		:= FwFldGet('ZZ1_VLRRAT')

If Alltrim(Str(nOperation))  $ "3/4"
	If dDtIni > dDtFim
		Alert("A data inicial não pode ser maior que data final!")
		lRetorno := .F.
	EndIf
EndIf

If Alltrim(Str(nOperation))  $ "3/4"
	If nValor >0 .and. nValorRat>0
		Alert("Somente um dos valores pode ser informado, Valor Litro ou Valor Total Rateio!")
		lRetorno := .F.
	ElseIf nValor ==0 .and. nValorRat ==0
		Alert("Informe o Valor Litro ou Valor Total Rateio para prosseguir!")
		lRetorno := .F.
	EndIf
EndIf




Return(lRetorno)         


/*/{Protheus.doc} E001Legenda
	@Funcao mostrar tela de legendas
	@uso EST - Estoque e Custo
	@author ACO - Brasoft
	@since 11/10/2019
/*/
User Function E001Legenda()

	Local aLegenda := {}

	AADD(aLegenda,{"BR_VERDE" 	,"Aguardando separação" 	})
	AADD(aLegenda,{"BR_CINZA" 	,"Em separação" 			})
	AADD(aLegenda,{"BR_AZUL"  	,"Separação finalizada" 	})
	AADD(aLegenda,{"BR_ROSA"  	,"Em conferência" 			})
	AADD(aLegenda,{"BR_ROXO"  	,"Conferência Finalizada"	})
	AADD(aLegenda,{"BR_VERMELHO","Documento fiscal gerado"  })

	BrwLegenda("Romaneio de Separação", "Fases", aLegenda)

Return Nil


/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³RATDEL	ºAutor  ³Totvs TM            º Data ³  00/00/00   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Função de validação da exclusão do rateio de sobras 		  º±±
±±º          ³							                                  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ Programa principal                                         º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
User Function RAT07DEL(_xCodigo, _xStatus)

//Se status indicar geração parcial ou fechamento total, não permite exclusão
If Alltrim(_xStatus) $ 'P/F'
	Alert("O rateio de sobras "+Alltrim(_xCodigo)+" gerou dados financeiros. Exclusão não permitida!!!")
	Return
EndIf

//Se status indicar geração parcial ou fechamento total, não permite exclusão
If Alltrim(_xStatus) $ 'T'
	Alert("O rateio de sobras "+Alltrim(_xCodigo)+" gerou contabilização. Exclusão não permitida!!!")
	Return
EndIf

//Confirmação com o usuário antes da exclusão.
If !MsgYesNo("Todos os dados calculados para o rateio "+Alltrim(_xCodigo)+" serão excluídos! Confirma exclusão?")
	Return
EndIf

//Posiciona nas tabelas ZZ1 e ZZ2 e executa a exclusão.
DbSelectArea("ZZ1")
DbSetOrder(1)
If DbSeek(xFilial("ZZ1")+_xCodigo)
	RecLock("ZZ1",.F.)
	ZZ1->(DbDelete())
	ZZ1->(MsUnlock())

	DbSelectArea("ZZ2")
	DbSetOrder(1)
	If DbSeek(xFilial("ZZ2")+_xCodigo)
		While ZZ2->(!Eof()) .and. ZZ2->ZZ2_CODIGO == _xCodigo
			RecLock("ZZ2",.F.)
			ZZ2->(DbDelete())
			ZZ2->(MsUnlock())
			ZZ2->(DbSkip())
		EndDo
	EndIf
EndIf

Return


// WHILE SC9->(!DBSEEK(xFILIAL("SC9")+ PEDIDO+ITEM ))
// nRet := MaLibDoFat(SC6->(RecNo()),nQtdLib,@lBloqCre,@lBloqEst,lAvalCre,lAvalEst,lLibPar,lTrans,NIL,NIL,NIL,NIL,NIL,0,nQtdLib2)
// DBCOMMITALL()
// ENDDO
//---------------------------------------------------------------------------
//     Rotina MaLibDoFat: libera os itens de pedido de vendas
//---------------------------------------------------------------------------                     
//     PARAMETROS
//---------------------------------------------------------------------------
// ExpN1: Registro do SC6                                      
// ExpN2: Quantidade a Liberar                                 
// ExpL3: Bloqueio de Credito                                  
// ExpL4: Bloqueio de Estoque                                  
// ExpL5: Avaliacao de Credito                                 
// ExpL6: Avaliacao de Estoque                                 
// ExpL7: Permite Liberacao Parcial                            
// ExpL8: Tranfere Locais automaticamente                      
// ExpA9: Empenhos ( Caso seja informado nao efetua a gravacao apenas avalia ).                                    
// ExpbA: CodeBlock a ser avaliado na gravacao do SC9           
// ExpAB: Array com Empenhos previamente escolhidos (impede selecao dos empenhos pelas rotinas)          
// ExpLC: Indica se apenas esta trocando lotes do SC9          
// ExpND: Valor a ser adicionado ao limite de credito          
// ExpNE: Quantidade a Liberar - segunda UM          
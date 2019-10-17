#INCLUDE "LOJA701.CH"
#INCLUDE "PROTHEUS.CH"
#INCLUDE "TCBROWSE.CH"
#INCLUDE "AUTODEF.CH"
#INCLUDE "FWMVCDEF.CH"
#INCLUDE "TBICONN.CH"
#INCLUDE "FWADAPTEREAI.CH"

#DEFINE _PICTURE	16
#DEFINE  LOG_DIR	"\AUTOCOM\LJ7"+cEmpAnt+StrTran(Alltrim(cFilAnt)," ","")+"\"
#DEFINE _MOEDA		6  			//Posicao do campo Moeda no array aPgtos(Localizacoes)
#DEFINE _EMISSAO	7  			//Posicao do campo Data de emissao no array aPgtos(Localizacoes)
#DEFINE _FORMATEF	"CC;CD"     //Formas de pagamento que utilizam operação TEF para validação
#DEFINE _FORMAPGTO	3			//Posicao do campo Forma de Pgto no array aPgtos
#DEFINE TEF_NAOUTILIZA          "1"
#DEFINE TEF_SEMCLIENT_DEDICADO  "2"
#DEFINE TEF_COMCLIENT_DEDICADO  "3"
#DEFINE TEF_DISCADO             "4"
#DEFINE TEF_LOTE                "5"
#DEFINE TEF_CLISITEF			"6"		//Utiliza a DLL CLISITE
#DEFINE CRLF					CHR(10)+CHR(13)

Static __lFirstLJ7	:= .T.
Static nHdlLJ7		:= -1
Static nDescRad		:= 1													// Valor da opcao escolhida
Static lMvLjPdvPa   := LjxBGetPaf()[2]										// Indica se é pdv
Static lPreVenda	:= SuperGetMV("MV_LJPRVEN",,.F.)						// Define se e pre-venda
Static aTitImp		:= {}
Static oMoviVp		:= NIL													// Objeto de movimento de venda perdida
Static lAlterOrc    := .F.                    								// Controle da opcaoo de alteração de orcamento
Static aProdOrig    := {}                                                  	// Guarda os produtos alter se ser alterado
Static aProdAlter   := {}													// Armazena os produtos alterados
Static nRecnoFo		:= 0													// Recno do Controle de Formulario selecionado pelo usuario atraves da especie de documento fiscal
Static lUsaLstPre	:= SuperGetMV("MV_LJLSPRE",,.F.) .AND. LjUpd78Ok() 		// Verifica se a funcionalidade Lista de Presente esta ativa e aplicada
Static lUsaIntFS	:= NIL 													// Verifica se a funcionalidade análise de credito esta ativa e habilitada
Static cMvLjIFSJu	:= SuperGetMV("MV_LJIFSJU",,"") 						// Regra de Calculo de juros e multas do Financial Services
Static cMVJurTipo	:= SuperGetMV("MV_JURTIPO",,"") 						// Regra de calculo de juros do Protheus
Static lLjMVRecIss	:= SuperGetMV("MV_LJRECIS",,.F.)						// Indica se ha desconto do iss no financeiro
Static lHomolPaf	:= LjHomolPaf()											// Verifica se está em modo de homologação do PAF
Static nTimerBrw 	:= If(SuperGetMv("MV_LJBW701",,0)>0,SuperGetMv("MV_LJBW701",,0)*1000,Nil)//Parametro que define o intervalo de tempo (em minutos) para atualizacao (Refresh) da MBrowse.
Static lPressedF5 	:= .F.													// Controla a disponibilidade da acao da tecla F5
Static lIsPafNfce	:= ExistFunc("STBPafNfce") .And. STBPafNfce()


//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Variaveis referente a "Recarga de Celular"³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Static lRCAtiva		:= .F.										// Verifica a configuracao de "Recarga de Celular" esta ativa.
Static cMVLJPREC	:= ""  										// Parametro com o codigo do produto tipo "Recarga de Celular".
Static aProdRcg   	:= {}										// Array com a relacao de produtos tipo "Recarga de Celular".
Static lRecarEfet	:= .F.										// Indica se foi efetuada alguma recarga na venda.
Static aRegTefRC	:= {} 										// Array com as movimentacoes do TEF da recargas

Static lVincServ	:= .F.										// Variavel para controle de mensagem produto com vinculo Servicos Financeiros
Static aNoFuncs		:= {} 										// Array de retorno do PE "LJNoFunc", que tem por objetivo retornar as Funcoes que devem ser desabilitadas.
Static aProdKit		:= {}										// Array para controlar os produtos referente a Kits

Static aVidaLinkD	:= {}										// array de detalhe (produto,qtde,preco) com o orcamento gerado no PBM VidaLink
Static aVidaLinkc	:= {}										// array cabecalhoe (Cliente,loja,etc) do orcamento gerado no PBM VidaLink
Static nVidaLink	:= 0 										// Indica se Itens veio do VidaLink. 0=Nao usa VidalInk. 1=Gravando VidaLink. 2=Gravou VidaLink
Static cSiglaSat	:= IIF( ExistFunc("LjSiglaSat"),LjSiglaSat(), "SAT" )	//Retorna sigla do equipamento que esta sendo utilizado
Static lIntDefPro	:= .F. 										// Processamento por mensagem única
Static lMFE			:= IIF( ExistFunc("LjUsaMfe"), LjUsaMfe(), .F. )		//Se utiliza MFE
Static _aItAuto		:= Nil										// Utilizado na rotina Lj7Reserva() para
Static lSaidaVld    := .T.  									// Controle para saida do valid M->LQ_PRODUTO
Static lShowMsg		:= .T.										// Validação para exibir a mensagem de validação da versão da NFC-e somente a primeira vez que acessar o sistema
Static cTecla		:= ""										//Armazena a ação do cliente, se pressionou F4, F5 ou F6

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±³Funcao    ³ Loja701	 ³ Autor ³ Vendas Cliente       ³ Data ³ 22/06/02 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Venda Assistida                                            ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ Automacao Comercial										  ³±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function LOJA701(	lAuto	, nOpc		, cCliente  , cLoja   ,;
					aCopyDoc, aCabAuto	, aItAuto	, aPrcAuto,;
					lSalVen	)

Local aCores 		:= Lj7DefLeg()									// Funcao que retorna o Array com as condicoes para cores do Browse
Local cLock 		:= cUserName+cEstacao							// Variavel que recebe o nome e a estação do usuario
Local aArea			:= SE4->(GetArea())

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³UTILIZADO NA VENDA ASSISTIDA CONCOMITANTE     ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Local aIcms       	:={}											// Array contendo informações do ICMS
Local nTamA1_LOJ  	:= TamSX3("A1_LOJA")[1] 						// Tamanho do campo A1_LOJA
Local cExistCpo 	:= ""                   						// Variável utilizada para guardar uma string para gravação no arquivo SX3
Local lRet 			:= .T.											// Variavel que controla o retorno
Local lCenVenda		:= SuperGetMv("MV_LJCNVDA",,.F.)				// Indica se existe integracao com cenario de vendas
Local cTabPadrao    := ""											// parametro da tabela de preco padrao
Local oTimer        := NIL 											// Objeto que determina tempo de execucao de uma rotina
Local xRet                                                          // Variavel de retormo do ponto de entrada
Local cFiltro	    := NIL                                          // Filtro da mBrowse (personalizado)
Local lTpl_PCL		:= HasTemplate("PCL")
Local lLJ7060      	:= ExistBlock("LJ7060")                     	// Verifica se existe o PE LJ7060
Local lFTVD7060    	:= ExistBlock("FTVD7060")                     	// Verifica se existe o PE FTVD7060 - Venda Direta
Local cNumCaixa 	:= xNumCaixa()									// Codigo do usuario ativo
Local lGE			:= ExistFunc("LjUP104OK") .AND. LjUP104OK() 	// Validação do Conceito Garantia Estendida
Local lSFinanc    	:= AliasIndic("MG8") .AND. SuperGetMV("MV_LJCSF",,.F.)	// Valida implementação do servico financeiro
Local lUseSat		:= LjUseSat()
Local aAreaSX3		:= {}
//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
Local lEmitNfce		:= LjEmitNFCe()									// Sinaliza se utiliza NFC-e
Local lFtvdVer12	:= LjFTVD()
Local cNomeProg		:= Iif(lFtvdVer12,"FATA701","LOJA701") 			// Nome da Rotina
Local lIntegDef		:= .F.
Local cMvVerNFCe	:= ""
Local cMsg			:= ""
Local dDate			:= CtoD("")										// Date()
Local dDtVerNfce	:= CtoD("30/09/2018")							// Data vigente para a NFC-e 3.10

Private cCadastro 	:= STR0122 										// "Venda Assistida"
Private aRotina 	:=	MenuDef()          							// Array que retorna com lista de aRotina
Private oPbm														// Objeto PBM
Private lAutoExec	:= .F.											// Verifica se esta sendo executada por EXECAUTO
Private lAutomato 	:= If(Type("lAutomatoX")<>"L",.F.,lAutomatoX)
Private cChkProd    := ""

Default lAuto 		:= .F.
Default nOpc		:= 0											// Opcao da funcao a Rotina
Default cCliente	:= ""											// Codigo do Cliente
Default cLoja		:= ""											// Loja do Cliente
Default aCopyDoc	:= {}											// 
Default aCabAuto	:= {}											// Array com os dados de cabeçalho para o ExecAuto
Default aItAuto		:= {}											// Array com os dados de itens para o ExecAuto
Default aPrcAuto	:= {}											// Array com os dados de parcela para o ExecAuto
Default lSalVen		:= .F.

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Verifica se as funcionalidades do EXECAUTO estão preenchidas³
//³para ativar a variavel estatica para execucao a partir de um³
//³EXECAUTO. Nesse modo, nao chama rotinas de ECF.			   ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If Len(aCabAuto) > 0 .And. Len(aItAuto) > 0
	lAutoExec := .T.
EndIf

lIntegDef := If(Type("lAutoExec") == "L", lAutoExec, .F.) .And. FWHasEAI("LOJA701",, .T., .T.) .AND. Lj701GtInD() //Verifica se eh Integracao via Mensagem Unica

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Forca DBSeek para prevenir falha a partir de Ponto de Entrada³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If AllTrim(SM0->M0_CODIGO + SM0->M0_CODFIL) <> AllTrim(cEmpAnt + cFilAnt)
	SM0->(DbSetOrder(1))
	SM0->(DBSeek(cEmpAnt + cFilAnt))
Endif

/*-------------------------------------------------------------
	Avisa ao usuário sobre a desativação da NFC-e 3.10
-------------------------------------------------------------*/
If !lAutoExec .AND.  lEmitNfce .And. !lUseSAt
	If ExistFunc("LjNfceMsg")
		cMsg := LjNfceMsg()
		
		If !Empty(cMsg)
			STPosMSG( "NT 2016.002" , cMsg, .T., .F., .F.)
		EndIf
	EndIf
EndIf

If lSFinanc .And. !lGe
	If !lAutoExec
		MsgInfo(STR0344) //"Para utilização de Serviço Financeiro, obrigatório definir o conceito de Garantia Estendida."
	Else
		Conout(STR0344) //"Para utilização de Serviço Financeiro, obrigatório definir o conceito de Garantia Estendida."
	EndIf

	Return Nil
EndIf

If LjNfPafEcf(SM0->M0_CGC) 
	//Conforme Requisito XIX do Ato Cotepe, valido se o PDV está em uso devido, de acordo com pendencias de envio de XML
	If !lAutoExec .AND. ExistFunc("STWFisVldEnvio") .And. ExistFunc("STBPafCSef") .And. STBPafCSef()
		lRet := STWFisVldEnvio( .F. , .F. , "" , .T. , .F.)
	EndIf

	aAreaSX3 := SX3->(GetArea())
	SX3->(dbSetOrder(2))
	//Esse trecho, deve ser removido e adicionado aos fontes do Template de Combustiveis nos UPD's
	If lTpl_PCL .AND. SX3->(dbSeek( "LR_BICO" )) .AND. !(AllTrim(SX3->X3_VALID) == "T_TpPclVlBico() .AND. ExistCpo('LEI',M->LR_BICO)")
		RecLock("SX3", .F.)
		REPLACE SX3->X3_VALID WITH "T_TpPclVlBico() .AND. ExistCpo('LEI',M->LR_BICO)"
		SX3->(MsUnlock())
	EndIf
	
	RestArea(aAreaSX3)
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Se nao tem midia cadastrada e for obrigatorio informar, mostra msg de alerta  ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If SuperGetMv("MV_LJRGMID",,0) == 2 .AND. ExistFunc("LjxValMid") .AND. !LjxValMid()
	IF !lAutoExec
		MsgInfo(STR0203) //"O parametro MV_LJRGMID esta com o preenchimento obrigatorio porem nao existem midias cadastradas, favor regularizar."
	Else
		Conout(STR0203) //"O parametro MV_LJRGMID esta com o preenchimento obrigatorio porem nao existem midias cadastradas, favor regularizar."
	EndIf
EndIf

If nModulo == 5 .OR. lFtvdVer12
	cCadastro := STR0148 //"Venda Direta"
EndIf

If lFtvdVer12
	AjustaHelp()
EndIf

//Faz a inclusao da natureza do SAT na tabela SX5
If !lAutoExec .And. nModulo == 12 .And. lUseSAt .And. lEmitNFCe

	If ExistFunc("LjSatErrCan")
		LjSatErrCan() //Faz a verificação dos parametros para recuperação.
	EndIf
	
	If ExistFunc("LjSatVerSx5")
		LjSatVerSx5()
	Else
		//Faz a inclusao da natureza do SAT na tabela SX5 - apos atualização dos fontes - remover daqui
		SX5->(DBSetOrder(1)) //X5_FILIAL + X5_TABELA + X5_CHAVE
		If !SX5->(DBSeek(xFilial("SX5")+Padr("42",Len(SX5->X5_TABELA))+"SATCE"))
			If SX5->(RecLock("SX5",.T.))
				SX5->X5_FILIAL	:= xFilial("SX5")
				SX5->X5_TABELA	:= "42"
				SX5->X5_CHAVE	:= "SATCE"
				SX5->X5_DESCRI	:= "Venda SAT"
				SX5->(MSUnlock())
			EndIf
		EndIf
	EndIf

EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Tratamento para identificar se as versoes dos fontes estao³
//³compativeis                                               ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lAutoExec
	If !Lj7VerifVer()
		ConOut(STR0241) //"Os Fontes Não Estao Compativeis"
		Help( " ", 1, "Help",, STR0241, 1, 0 ) //"Os Fontes Não Estao Compativeis"
		Return
	EndIf
Else
	Lj7VerifVer()
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Verifica se o parametro MV_CONDPAD esta preenchido e com  ³
//³um codigo valido                                          ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
DbSelectArea("SE4")
DbSetOrder(1)
If cPaisLoc == "ARG" .AND. Empty(SuperGetMV("MV_CONDPAD")) .Or. !DbSeek(xFilial("SE4")+SuperGetMV("MV_CONDPAD")) // Manter o tratamento somente para Argentina.
	cMsg := STR0188 + CRLF +;		// "O parâmetro MV_CONDPAD não está configurado corretamente."
			STR0189					// "Avise o administrador do sistema!"
	If !lAutoExec
		MsgInfo(cMsg)
	Else
		ConOut(cMsg)
		Help( " ", 1, "Help",, cMsg, 1, 0 )
	EndIf
	RestArea(aArea)
	Return NIL
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Verifica se o CNPJ cadastrado na impressora, eh o mesmo do SIGAMAT³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lFiscal .AND. !nModulo == 5 .AND. !lAutoExec .AND. !lEmitNfce
	If !LjEcfIFCNPJ()
		Return NIL
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Validacao do numero sequencial de documentos³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lFiscal .AND. !LjDocSeq()
	Return Nil
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Se utiliza cenario de vendas, verifica se a tabela esta valida³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lCenVenda .And. SuperGetMV("MV_LJRETVL",,"3") == "3" //1=Retorna o menor preco de uma tabela | 2=Retorna o maior preco de uma tabela | 3=Considera preco da tabela configurada no parametro MV_TABPAD

	cTabPadrao := Pad(SuperGetMv("MV_TABPAD"),TamSx3("DA0_CODTAB")[1])
	DA0->(DbSetOrder(1))

	If !DA0->(DbSeek(xFilial("DA0")+cTabPadrao))
		MsgStop(STR0143) //"Tabela de preco invalida no parametro MV_TABPAD"
		Return Nil
	EndIf
	
	//Não deve validar tabela de preço quando integração EAI (Mensagem Unica), pois deve respeitar o preco recebido
	If !lIntegDef .And. !MaVldTabPrc(cTabPadrao)
		Return Nil
	EndIf

EndIf

If lFiscal .AND. cPaisLoc == "BRA" .AND. !lEmitNfce
	If !lAutoExec
		LjMsgRun(STR0075,,{|| aIcms := LjSetAliq(),CLR_HRED } ) // Aguarde, verificando a impressora fiscal...
	Else
		aIcms := LjSetAliq()
	EndIf
EndIf
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Verifica se os campos foram criados corretamente L1->LQ / L2->LR ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
CheckCampos("SL1", "SLQ")
CheckCampos("SL2", "SLR")

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³LIBERA CAMPOS SER 3  ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If  AllTrim(SuperGetMv("MV_LOCALIZ",,.F.)) == "S"	.AND. Lj7EndSer3()
	Pyme_Dic_Ajust("SL2")
	Pyme_Dic_Ajust("SLR")
EndIf
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Seleciona a área para que seja criado o arquivo SLQ...³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
DbSelectArea( "SLQ" )
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Seleciona a área para que seja criado o arquivo SLR...³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
DbSelectArea( "SLR" )

DbSelectArea( "SL1" )
DbSetOrder(1)     // L1_FILIAL + L1_NUM

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Seleciona tabela SLF para posicionamento do usuario caixa ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
DbSelectArea("SLF")
DbSetOrder(1) //LF_FILIAL+LF_COD

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Termino do acerto na base.                                               ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Faz tratamento para que usuarios não fiscal utilizem a rotina sem ser bloqueados ³
//³por motivo de concorrencia de perifericos já que estes não alocam.               ³
//³Não permite que usuario fiscal tenha acesso a interface SIGAMDI.                 ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If SUBSTR(Posicione("SLF",1,xFilial("SLF")+cNumCaixa,"LF_ACESSO"),3,1)$ "SX" 	// verifica se o usuario é fiscal
	If oApp:lMDI    								// verifica a propriedade do objeto verdadeiro se MDI
		If !lAutoExec
			If nModulo == 5
				MsgStop(STR0412) //"O acesso a rotina venda direta na interface SIGAMDI não é permitido"
			Else
				MsgStop(STR0126) //"O acesso a rotina venda assistida na interface SIGAMDI não é permitido"
			EndIf			
		Else
			ConOut(STR0126)
			Help( " ", 1, "Help",, STR0126, 1, 0 )
		EndIf
		lRet  := .F.
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Executa a inicializacao das variaveis de controle do Loja, quando o LOJA701³
//³for acionado a partir do faturamento                                       ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lRet .AND. (nModulo == 5 .OR. lFtvdVer12)
	OpenLoja()
EndIf

If lLj7060 .AND. !lFtvdVer12
	xRet := ExecBlock( "LJ7060", .F., .F. )
	If ValType(xRet) == "C"
	    cFiltro  := xRet
	EndIf
EndIf

If lFTVD7060 .AND. lFtvdVer12
	xRet := ExecBlock( "FTVD7060", .F., .F. )
	If ValType(xRet) == "C"
	    cFiltro  := xRet
	EndIf
EndIf

If lRet .AND. !lAutoExec .AND. (lEmitNFCe .Or. lIsPafNfce) .AND. LjProfile(3)	//verifica se o usuario é fiscal
	//Verifica se a ultima venda deste PDV ficou com processamento pendente devido queda do sistema.
	//NFC-e
	If !lUseSAT .And. ExistFunc("LjNFCeUltV")
		LjNFCeUltV()
	
	//SAT
	ElseIf lUseSAT
		If ExistFunc("LjSATUltV")
		 	LjMsgRun(STR0416,STR0417,{|| lRet := LjSATUltV() } ) //"Aguarde.... Verificando se há vendas a serem recuperadas" #
		Else
			lRet := LJSATInicia()
		EndIf
	EndIf
EndIf

If lRet
	If lAuto
		DbSelectArea('SL1')
		nPos := Ascan(aRotina,{|x| x[4]== nOpc})
		If ( nPos <> 0 )
			bBlock := &( "{ |a,b,c,d,e,f,g,h| " + aRotina[ nPos,2 ] + "(a,b,c,d,e,f,g,h) }" )
			Eval( bBlock, Alias(), (Alias())->(Recno()),nPos,Nil,cCliente,cLoja,Nil,aCopyDoc)
		EndIf
	ElseIf lAutoExec
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		// Integração Venda Direta x Gestão de Concessionarias	   ³
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		If lFtvdVer12
			If nOpc == 6 //Insere Opção de alteração de parcelas que funciona apenas via execauto
				AAdd(aRotina,NIL)
				AIns(aRotina,6)
				ARotina[6] := { STR0242, "Lj7Venda" 	, 0 , 6 , , .T. }	//"Altera Parcelas"
			EndIf
		EndIf

		DbSelectArea('SL1')
		nPos := Ascan(aRotina,{|x| x[4]== nOpc})
		If ( nPos <> 0 )
			bBlock := &( "{ |a,b,c,d,e,f,g,h,i,j,k,l| " + aRotina[ nPos,2 ] + "(a,b,c,d,e,f,g,h,i,j,k,l) }" )
			Eval(	bBlock	,Alias()	,(Alias())->(Recno())	,nPos	 ,;
					Nil		,Nil		,Nil					,Nil	 ,;
					Nil		,aCabAuto	,aItAuto				,aPrcAuto,;
					lSalVen	)
		EndIf
	Else
		If ExistFunc("P_LJ7051") .AND. !lFtvdVer12
			P_LJ7051( 2 , @aCores )
        EndIf

		If ExistFunc("U_LJ7051") .AND. !lFtvdVer12
			U_LJ7051( 2 , @aCores )
		EndIf

		If ExistFunc("P_FTVD7051") .AND. lFtvdVer12
			P_FTVD7051( 2 , @aCores )
		ElseIf ExistFunc("U_FTVD7051") .AND. lFtvdVer12
			U_FTVD7051( 2 , @aCores )
        EndIf

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Em base de dados DBF, cFiltro so' e' executado ao entrar³
		//³a primeira vez. Ao retornar de um atendimento da Venda  ³
		//³Assistida, o filtro e' desfeito. Usando Set Filter antes³
		//³da mBrowse, o filtro permanece.                         ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If ( "DBF" $ __cRDD ) .And. !IsBlind() .And. !lFtvdVer12
			dbSelectArea("SL1")
			Set Filter to &cFiltro
		EndIf

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³LR5 = Seleciona Versão 11.5                             ³
		//³Modificada chamada do Objeto mBrowse.                   ³
		//³Versão 11.5 o parâmetro CFiltro é inserido na posição 23³
		//³Versão 11.0 o parâmetro CFiltro é inserido na posição 19³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		mBrowse( ,,,,"SL1",,,,,,aCores,,,,{ |x| Lj7Timer( @oTimer, x ) },,,.F.,,If(!lAutoExec,nTimerBrw,0),{ || Lj7AtuBrw() },,cFiltro)
	EndIf
EndIf
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Recupera a Integridade dos dados                             ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
RetIndex("SL1")
dbSetOrder(1)
Set Filter to

Return Nil

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±³Funcao    |MenuDef	³ Autor ³ Vendas Cliente        ³ Data ³12/12/06  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Funcao de definição do aRotina                             ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Retorno   ³ aRotina   retorna a array com lista de aRotina             ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso       ³ SIGALOJA                                                   ³±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Static Function MenuDef()

Local aRotina		:= {}	// Array com as rotinas da mBrowse
Local aRotina2              // Array com as rotinas(submenu) da mBrowse
Local aNRotina				// Retorno do PE para adicionar no aRotina
Local nX			:= 0
Local lCentPDV		:= IIf(ExistFunc("LjGetCPDV"), LjGetCPDV()[1] , .F. )	// Central de PDV
Local lInutili  	:= SuperGetMV("MV_INUTILI",,.F.)						// Indica se a rotina Inutilização de NFC-e vai estar disponivel no menu
Local lUseSat		:= .F.													// Controle de SAT ativo
Local lLjNFCeRet 	:= ExistFunc("LjNFCeRetr")								// Indica se a funcao de retransmissao de NFC-e esta compilada
Local lHabilFilz	:= SuperGetMV("MV_LJLBNT",,0) > 0						// Habilita Finaliza Venda - Vide doc:http://tdn.totvs.com.br/display/PROT/TUXK67_DT_Disponibilizar_Emissao_Nota_Fiscal_Interestadual_Venda_Assistida
Local lLjSATComp	:= FindFunction("LjSATComp")							// Habilita o menu para a emissão do CF-e SAT Complementar de ICMS
Local lHabFinLot   	:= SuperGetMV("MV_LJLOTNF",,.F.)							// Habilita finalizar oraçamentos em lote gerando NFCE
//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
Local lEmitNfce	:= LjEmitNFCe()// Sinaliza se utiliza NFC-e
Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida
Local lFisNota		:= SuperGetMV("MV_FISNOTA",,.F.)	// Verifica se esta configurado para emissao de NF

//Valida configuracao de SAT (Protecao para SIGAMDI)
If (!oApp:lMDI .Or. Select("SLG") > 0) .AND. ExistFunc("LjUseSat") .AND. LjUseSat()
	lUseSat := .T.
EndIf

/*----------------------------------------------------
	********************** ATENÇÃO **********************							
	Conforme verificado com a equipe do Framework, o nOpc 
	setado na 4 posição do aRotina não é verificado 
	e sim a posição que do aRotina que foi "clicada", 
	portanto deve-se inserir no array 
	o menu de acordo com o nOpc desejado.
	Caso a rotina necessite realmente da leitura do 4 param
	deve-se :
	
	nOpc := aRotina[x][4] //captura o nOpc conforme setado no aRotina
	
	caso contrario, seja pego a posição do aRotina que foi clicado.
	
------------------------------------------------------*/
aAdd(aRotina, { STR0002, "AxPesqui" 	, 0 , 1 , , .F. })	//"Pesquisar"
aAdd(aRotina, { STR0003, "LJ7Venda" 	, 0 , 2 , , .T. })	//"Visualização"
aAdd(aRotina, { STR0004, "Lj7Venda" 	, 0 , 3 , , .T. })	//"Atendimento"

If lCentPDV .AND. !lFtvdVer12

	If LjNfPafEcf(SM0->M0_CGC)

		If lHabilFilz
			Aadd(aRotina, { STR0005, "Lj7Venda" 	, 0 , 4 , , .T. })		//"Finaliza Venda"
		EndIf

		If lPreVenda
			aAdd(aRotina, { STR0211, "Lj7Venda"		, 0 , 5 , , .T. })		//"Alteracao Orcamento"
		Else
			aAdd(aRotina, { STR0235, "Lj7Venda" 	, 0 , 4 , , .T. })		//"Alt. &Orcamento"
			aAdd(aRotina, { STR0165, "LJ7Orcam" 	, 0 , 4 , , .T. })		//"DAV"
			aAdd(aRotina, { STR0211, "Lj7Venda"		, 0 , 5 , , .T. })		//"Alteracao Orcamento"
		EndIf

	Else

		Aadd( aRotina ,	{ STR0006, "LJ7Orcam" 	, 0 , 4 , , .T. } )	//"Orçamento"
		Aadd( aRotina ,	{ STR0235, "Lj7Venda" 	, 0 , 4 , , .T. } )	//"Alt. &Orcamento"

		If lEmitNfce .Or. lIsPafNfce
			aRotina2:= {{ STR0309, "LjNFCePar"	,0,3},; 	//"Parâmetro"
        	       		{ STR0310, "LjNFCeCfg"	,0,3},; 	//"Configuração"
            	   		{ STR0335, "LjNFCeEven"	,0,3},; 	//"Eventos"
    	           		{ STR0311, "LjNFCeMnt"	,0,3},;		//"Monitor"
               			{ STR0317, "LjNFCeExp"	,0,3} }		//"Exportar"

			If lLjNFCeRet
				Aadd( aRotina2, {STR0386, "LjNFCeRetr", 0, 3} )	//"Retransmissão"
			EndIf

			If !lUseSat
				Aadd( aRotina, {STR0312, aRotina2		, 0, 3, , .T. } )	//"NFC-e"
			EndIf
		EndIf

	EndIf

ElseIf lEmitNfce .Or. lIsPafNfce
	aRotina2:= { 	{ STR0309, "LjNFCePar"	,0,3},; 	//"Parâmetro"
               		{ STR0310, "LjNFCeCfg"	,0,3},; 	//"Configuração"
               		{ STR0335, "LjNFCeEven"	,0,3},; 	//"Eventos"
               		{ STR0311, "LjNFCeMnt"	,0,3},;		//"Monitor"
               		{ STR0317, "LjNFCeExp"	,0,3} }		//"Exportar"
    
    If lHabFinLot
        Aadd(aRotina2, { STR0394, "LjNFCeLot"     , 0 , 3 } ) //"Enviar Lote"
    EndIf
	If lLjNFCeRet
		Aadd( aRotina2, {STR0386, "LjNFCeRetr", 0, 3} )	//"Retransmissão"
	EndIf

	Aadd(aRotina, { STR0005, "Lj7Venda" 	, 0 , 4 , , .T. } )	//"Finaliza Venda"
	Aadd(aRotina, { STR0006, "LJ7Orcam" 	, 0 , 4 , , .T. } )	//"Orçamento"
	Aadd(aRotina, { STR0299, "Lj7140Exc"	, 0 , 6 , , .T.	} )	//"Excluir NF/Orc/Ped"

	If lInutili
		Aadd(aRotina, {STR0345,"SpedNFeInut", 0	, 3	,0, Nil	} )	//"Inutilização"
	EndIf

	If lUseSat
		Aadd(aRotina, { "Reimpressão "+cSiglaSat, "LJSatReImp"	, 0 , 4 , , .T.	} )	//"Reimpressão SAT"
		If lLjSATComp
			aAdd(aRotina, { STR0433, "LjSATComp()"	, 0 , 9 , , .T. })			//"SAT Complementar"
		EndIf	
	Else
		Aadd(aRotina, { STR0300, "Lj7ImpDanfe"	, 0 , 4 , , .T.	} )			//"Imprimir NFC-e"
	EndIf

	//somente usa aRotina2 caso seja NFC-e
	If !lUseSat
		Aadd(aRotina, { STR0312, 		aRotina2		, 0 , 3 , , .T. } )	//"NFC-e"
	EndIf

ElseIf LjNfPafEcf(SM0->M0_CGC) .AND. !lFtvdVer12

	If lMvLjPdvPa .OR. lHabilFilz
		Aadd(aRotina, { STR0005, "Lj7Venda" 	, 0 , 4 , , .T. })	//"Finaliza Venda"
	EndIf

	If lMvLjPdvPa
		Aadd(aRotina, { STR0169, "LJ7Import" 	, 0 , 3 , , .T. })	// "Importacao"
	ElseIf lPreVenda
		Aadd(aRotina , { STR0235, "Lj7Venda" 	, 0 , 4 , , .T. })	// "Alt. &Orcamento"
		Aadd(aRotina , { STR0211, "Lj7Venda"  	, 0 , 5 , , .T. })	// "Alteracao Orcamento"
	Else
		Aadd(aRotina , { STR0235, "Lj7Venda" 	, 0 , 4 , , .T. })	// "Alt. &Orcamento"
		Aadd(aRotina , { IIF(lFisNota,STR0165+"/"+STR0006,STR0165), "LJ7Orcam" 	, 0 , 4 , , .T. })	// "DAV"						
		Aadd(aRotina , { STR0211, "Lj7Venda"  	, 0 , 5 , , .T. })	// "Alteracao Orcamento"
	EndIf

Else
	Aadd( aRotina , { STR0005, "Lj7Venda" 	, 0 , 4 , , .T. })	// "Finaliza Venda"
	Aadd( aRotina , { STR0299, "Lj7140Exc"	, 0 , 6 , , .T.	})	// "Excluir NF/Orc/Ped"

	If !lPreVenda
		Aadd( aRotina , { STR0006, "LJ7Orcam" 	, 0 , 4 , , .T. })	// "Orçamento"
		Aadd( aRotina , { STR0388, "LojC090"    , 0 , 4 , , .T. })	// "Consulta Tracker"
		Aadd( aRotina , { STR0211, "Lj7Venda"   , 0 , 5 , , .T. })	// "Alteracao Orcamento"
	EndIf

EndIf

//Aprovação de medicamentos para Farmaceutico - Template Drogaria
If HasTemplate("DRO") .AND. ExistFunc("T_DroVlApr")
	Aadd( aRotina , { STR0425, "T_DroVlApr" 	, 0 , 4 , , .T. })	// "Aprovar &Medicamentos"
EndIf

Aadd(aRotina , { STR0392, "Lj7CopOrc"	, 0 , 7 , , .T. })	//"Copia Orcamento"
aAdd(aRotina , { STR0007, "Lj7Legenda"	, 0 , 8 , , .T. })	//"Legenda"

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Integração Financial Services                        ³
//³Novos menus para liberação manual do Crédito e       ³
//³Re-envio da análise de crédito reprovada para a mesa ³
//³de crédito                                           ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lUsaIntFS == NIL
	lUsaIntFS	:= SuperGetMV("MV_LJINTFS",,.F.) .And. LjUpd90Ok(, !IsBlind())
EndIf
If lUsaIntFS .And. !(LjNfPafEcf(SM0->M0_CGC) .and. lMvLjPdvPa)
	aAdd(aRotina ,  { STR0258 ,"Lj7FSLAn"   , 0 , 2 , , .T. }) //"Lib Man Analise Cred Financial"
	aAdd(aRotina ,	{ STR0259 ,"Lj7FSRAn"   , 0 , 2 , , .T. }) //"Reenv Analise Cred Financial"
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³PE para acrescentar mais opcoes no aRotina³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If ExistBlock("LJ7053") .AND. !lFtvdVer12
	aNRotina	:= 	ExecBlock( "LJ7053", .F., .F. )

  	If ValType(aNRotina) == "A"
  		For nX	:= 1 To Len(aNRotina)
			If Len(aNRotina[nX]) == 6	// somente adiciona se o tam for compativel
				AAdd(aRotina , aNRotina[nX])
			EndIf
		Next nX
  	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³PE para acrescentar mais opcoes no aRotina(Venda Direta) ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If ExistBlock("FTVD7053") .AND. lFtvdVer12
	aNRotina	:= 	ExecBlock( "FTVD7053", .F., .F. )

  	If ValType(aNRotina) == "A"
  		For nX	:= 1 To Len(aNRotina)
			If Len(aNRotina[nX]) == 6	// somente adiciona se o tam for compativel
				AAdd(aRotina , aNRotina[nX])
			EndIf
		Next nX
  	EndIf

EndIf

Return aRotina

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±³Funcao    ³Lj7Venda   ³ Autor ³ Vendas Cliente       ³ Data ³ 22/06/02 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Venda Assistida                                            ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ Automacao Comercial										  ³±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7Venda(cAlias  , nReg 	, nOpc      , aEnch		,;
                  cCliente, cLoja 	, cFilContra, aCopyDoc	,;
                  aCabAuto,	aItAuto	, aPrcAuto	, lSalVen	)

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Define objetos da tela de Venda Assistida, sao eles: 	 	 ³
//³  															 ³
//³ Objetos principais:											 ³
//³ Dialog, Enchoice, ListBox, Getdados, Panel 1, Panel 2		 ³
//³ O objeto Getdados esta declarado como Private - oGetVA       |
//³  															 ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Local oEncVA																			// Objeto
Local oTitulo																			// Objeto Titulo
Local oPanVA1																			// Objeto VA1
Local oPanVA2																			// Objeto VA2
Local oPanVA3																			// Objeto VA3

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Area da tela para o Define da Dialog e Posicao dos objetos	 ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Local aSize1 	:= MsAdvSize()															// Tamanho da tela
Local aPosObj1	:= {}																	// Area total de trabalho
Local aPosObj2	:= {}																	// Toolbar direita
Local aPosObj3	:= {}																	// Enchoice, Getdados, Panel
Local aPosObj4	:= {}																	// Panel que contem Pagamentos
Local aPosObj5	:= {}																	// Objetos dentro do painel de Totais

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Define outras variaveis Local                                ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Local aCpoEnc	:= {}																	// Campos que aparecerao na Enchoice (SL1)
Local aCpoGDa	:= {}																	// Campos que aparecerao na Getdados (SL2)
Local aCpoGDaDet:= {}																	// Campos que irao conter os detalhes dos produtos
Local aMenu     := Array(4)																// Array com as opcoes de menu
Local aAlterGD	:= {}																	// Array com os campos alteraveis da GetDados
Local aBonus	:= {}																	// Lista de produtos bonificados (cenario de vendas)
Local nCount1	:= 0																	// Contador 1
Local nCount2	:= 0																	// Contador 2
Local nCount3	:= 0																	// Contador 3
Local bBloco 																			// Bloco de codigo a executar
Local cNumCaixa := xNumCaixa()															// Codigo do usuario ativo
Local nRegSL1 	:= SL1->(Recno())														// Registro do SL1 que será tratado no retorno para a MBrowse
Local lAltDados := .T.																	// Variavel que ira controlar a permissao para alterar as informarcoes da enchoice e getdados
Local nTent 	:= 0																	// Nr. de tentativas
Local cMay		:= ""																	// Guarda o cod. do orcamento a ser verificado
Local nSaveSx8 	:= GetSx8Len()															// Guarda a posicao salva do SX8
Local nX        := 0																	// Auxiliar nos comandos For...Next
Local aFuncUsu  := {}                              										// aFuncoes de usuario.
Local aAtalho   := {}                              										// Controle de atalhos da toolbar
Local aFuncTpl  := {}                              										// aFuncoes de Template.
Local lContAtend:= .T. 																	// Retorno do ponto de entrada LJ7032. Se FALSO retorna para a MBrowse e não permite continuar.
Local lCenVenda	:= SuperGetMv("MV_LJCNVDA",,.F.)										// Indica se existe integracao com cenario de vendas
Local lPrcBonus	:= .F.																	// Indica se o bonus foi processado
Local lGE		:= ExistFunc("LjUP104OK") .AND. LjUP104OK() 							// Validação do Conceito Garantia Estendida

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Variaveis utilizadas no calculo de fator                     ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Local lUsouFator	:= .F. 																// Indica se esta usando fator financeiro na venda
Local nFator		:= 0																// Indica qual eh o fator financeiro
Local cAdmFator		:= ""																// Indica a Adm. usada no fator financeiro

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Variaveis com informacoes de parametrizacoes                 ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Local cCliPad   := IIf( Valtype(cCliente) <> "C", SuperGetMV( "MV_CLIPAD" ), cCliente )	// Cliente
Local cLojPad   := IIf( Valtype(cLoja)  <> "C", SuperGetMV( "MV_LOJAPAD" ), cLoja )		// Loja
Local aCopyDev	:= Iif( Valtype(aCopyDoc) == "U", {}, aCopyDoc )						// Dados para troca
//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida
Local cVendPad  := Iif(lFtvdVer12,If(ExistBlock("FT701VP"), ExecBlock("FT701VP",.F.,.F.), SuperGetMV( "MV_VENDPAD" )),SuperGetMV( "MV_VENDPAD" ))                                          	// Variavel que recebe o conteudo do parametro MV_VANDPAD

//-- Controle de Log.
Local nHandle     := -1
Local cLjArq      := Space(8)
Local lLog1       := ( SubStr(LJGetProfile("LOGERRO"),1,1) == "S" )
Local aCloaCols   := {}
Local cImpressora := LjGetStation("IMPFISC")
local cPorta	  := LJGetStation("PORTIF")
Local aVetTemp    := {}
Local lSair		  := .F.
Local aDocDev     := {}                 // Serie e numero do documento de entrada gerado pela rotina troca/devolucao
Local lAlterPre   := .F.				// Se permite alteracao de preco

Local nPosProd 	  := 0
Local nPosTES 	  := 0
Local nPosQuant   := 0
Local nPosPRCTab  := 0
Local nPosValDesc := 0
Local nAtalho     := 5			// Controle das teclas de atalho da toolbar
Local lTefPendCS  := .F.		// Controla se existe TEF Pendente da CLISITEF
Local aTefBKPCS   := {}			// Guarda a transacao TEF Pendente da CLISITEF
Local cAlterCond  := ""			// Guarda a condicao de pagamento escolhida
Local nVlrAcrsFi  := 0 			// Variavel para calculo do juros sobre o valor financiado
Local aRet		  :={} 		//Utilizado no ponto de entrada FT701BTN
Local lAlteraPrc  := Iif(nOpc == 6 .AND. lFtvdVer12,(nOpc:=2,.T.),.F.) //Alteração de preço com integração Venda Direta x Gestão de Concessionarias

//³Release 11.5 - Controle de Formularios ³
//³Paises:Chile/Colombia - F1CHI 		  ³
Local lCFolLocR5:= 	SuperGetMv("MV_CTRLFOL",,.F.) .AND. cPaisLoc$"CHI|COL" .AND. !lFiscal
Local cSigEspFo	:= ""			//Especie de documento fiscal selecionado pelo usuario no inicio da venda.
Local cDocFo	:= ""			//Numero do documento fiscal informado pelo usuario no inicio da venda via controle de formularios.

Local bSalOrc   := {||	IIf(LjKeyFuncs(1) .And. (Lj701VRegD("SA1")) .AND. (Lj701VRegD("SA3")) .AND. (Lj701VRegD("SE4")) ,;
						IIf(Lj7SetKeys() .AND. Lj7VldNCC( nOpc ), (Lj7AtuPgto(cAlterCond),IIf(LjVldF4(), IIf( lLog1, ( aCloaCols := aClone(aCols), LJGrLog(@nHandle, M->LQ_NUM, @cLJArq, cImpressora, cPorta) ), Nil ), Nil), ;
						Iif(LjVldF4(), Iif( nOpc <> 2.OR. lAlteraPrc, LJ7Gravacao(If(lAlteraPrc,4,1), If(lAlteraPrc,1,nOpc), nSaveSX8, @lSair, nHandle, aDocDev, lLJDTOrc, @lTefPendCS, @aTefBKPCS, NIL, NIL, nVlrAcrsFi), Nil ), Nil ), ;
						Iif(LjVldF4(), Iif( lLog1, LJDelLog(	nHandle, aCloaCols, aCols, cLJArq, M->LQ_NUM, M->LQ_DESCONT, M->LQ_CLIENTE	, M->LQ_LOJA), Nil ), Nil ) , ;
						Iif(LjVldF4(), Iif( lSair, IIF(!lAutoExec,oDlgVA:End(), Nil ), Nil ), Nil )), Nil ), Nil ) }

Local bSalVen   := {|| LjSalvaVda(	cAlterCond	, lLog1		, @lPrcBonus, nOpc		, @lTefPendCS	,;
									@aTefBKPCS	, @aBonus	, nSaveSX8	, @lSair	, aDocDev		,;
									lLJDTOrc	, nVlrAcrsFi, cSigEspFo	, cDocFo	, aDadosCNeg	,;
									@lErroNFCe	, @lErroNFe ) }

Local bSalOrcAl := {||	Lj7AltOrc() .AND. oDlgVA:End()}

Local bSair     := {||	IIf(LjKeyFuncs(3) .And. Lj7SetKeys(), (Iif( lLog1, ( aCloaCols := aClone(aCols), LJGrLog(@nHandle, M->LQ_NUM, @cLJArq, cImpressora, cPorta) ), Nil ), ;
						Iif( lLog1, LJDelLog(	nHandle		, aCloaCols		, aCols			, cLJArq, ;
						M->LQ_NUM	, M->LQ_DESCONT	, M->LQ_CLIENTE	, M->LQ_LOJA), Nil ), ;
						MBrChgLoop(.F.), oDlgVA:End()), Nil )	}

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Inicializa como Cupom Fiscal.³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Local lVAssConc	 := LjVassConc(1)				//Indica se o cliente utiliza a Vda Assistida Concomitante

Local nTamL4_FORMAID  	:= 0
Local nTamL4_CHEQUEID	:= IIf(SL4->(ColumnPos("L4_CHEQID"))>0,TamSx3("L4_CHEQID")[1],1)	// Tamanho do campo L4_CHEQID
Local nTamLQ_VEND		:= TamSx3("LQ_VEND")[1]    		// Tamanho do campo LQ_VEND
Local nTamLQ_NOMVEND	:= TamSx3("LQ_NOMVEND")[1] 		// Tamanho do campo LQ_NOMVEN
Local nTamLQ_CLIENTE	:= TamSx3("LQ_CLIENTE")[1] 		// Tamanho do campo LQ_CLIENT
Local nTamLQ_LOJA		:= TamSx3("LQ_LOJA")[1]   		// Tamanho do campo LQ_LOJA
Local nTamLQ_NOMCLI		:= TamSx3("LQ_NOMCLI")[1] 		// Tamanho do campo LQ_NOMCLI
Local nTamADIC5			:= 0 		// Tamanho do campo LQ_ADIC5
Local nTamADIC61		:= 0 		// Tamanho do campo LQ_ADIC61
Local nTamADIC62		:= 0 		// Tamanho do campo LQ_ADIC62
Local nTamADIC7			:= 0 		// Tamanho do campo LQ_ADIC7
Local nRetPis 			:= SuperGetMV("MV_VRETPIS")		// Valor minimo para dispensa de retencao de PIS.
Local nRetCof 			:= SuperGetMV("MV_VRETCOF")		// Valor minimo para dispensa de retencao de COFINS
Local nRetCsl 			:= SuperGetMV("MV_VRETCSL")		// Valor minimo para dispensa de retencao de CSLL
Local lIntegLoja 		:= SuperGetMV("MV_INTEEMS")		// Define se existe integracao do SIGALOJA com o sistema EMS
Local lTefMilha 		:= SuperGetMV("MV_TEFMILH")		// Ativa as transacöes de milhagens
Local cTpComiss			:= SuperGetMv("MV_LJTPCOM",,"1")//Tipo de calculo de comissao utilizado (1-Para toda a venda (padrao),2-Por item)
Local cLJDTORC			:= SuperGetMV("MV_LJDTORC")		// Verifica se a data do orcamento deve ser atualizada
Local lMenNota			:= SuperGetMV("MV_LJMENNO",,.F.) 		// Verifica se esta habilitado a apresentacao do campo de observacao da nota fiscal
Local lLJDTOrc			:= .T.							// Controle da atualizacao da data do pagamento
Local aLeg				:= LjAnalisaLeg(24)				// Verifica se o estado e Amazonas
Local lPedVen			:= LjPedVen(.F.)				//Verifica se esta preparado para emissao de Ped. Venda
Local lTemGeraNOrc		:= .F.							//Se tem função especial para numero de orcamento
Local lValida           := .F.
Local lUsaTurno			:= lPedVen	.AND. LJAnalisaLeg(47)[1]	//Verifica se esta preparado para utilzar a selecao de turnos de entrega
Local lCalcIPI          := .T.
Local nDocSai       	:= 1     								// Variavel para controle do documento emitido: 1=Cupom;2=Nota;3=Retorna a venda
//Variaveis do EXECAUTO
Local aValidGet			:= {}									//variavel contendo os campos de cabeçalho
Local lRet				:= .F.									//variavel logica para verificar se continua o processamento ou nao
Local AutoReadVar		:= ""									//Variavel usada para atualizar as variaveis de memoria no EXECAUTO
Local aColsAux			:= {}									//Variavel auxiliar do aCols
Local nPos				:= 0									//Ponteiro de localizacao dentro do array
Local nY				:= 0									//Contador
Local nTamLR_ITEM		:= TamSX3("LR_ITEM")[1]					//Variavel que guarda o tamanho do campo LR_ITEM
Local cItem				:= Replicate("0",nTamLR_ITEM)			//Variavel para o tratamento do sequencial do item
Local cFrmAux			:= ""									//Forma de Pagamento Auxiliar
Local nPosDtItem		:= 0									// Posicao do numero do item
Local nPosDtProd		:= 0									// Posicao do Codigo do produto
Local nPosItem			:= 0									// Posicao do numero do item
Local nPosLQ_CONDPG		:= IIF(lAutoExec,Ascan(aCabAuto,{|x| Alltrim(x[1]) == "LQ_CONDPG"}),0)
Local nPosLQ_JUROS	    := IIF(lAutoExec,Ascan(aCabAuto,{|x| Alltrim(x[1]) == "LQ_JUROS"}),0)
Local lCatProd			:= SuperGetMv("MV_LJCATPR",.F.,.F.)
Local aDadosCNeg		:= {}									//vetor com as informacoes referentes a Condicao Negociada
//³Release 11.5 - Cartao Fidelidade³
Local lLjcFid	 		:= SuperGetMv("MV_LJCFID",,.F.) .AND. CrdxInt()	//Indica se a recarga de cartao fidelidade esta ativa
Local lCAT83 			:= ExistFunc("FISA023") .And. SuperGetMV("MV_CAT8309",,.F.) // Verifica CAT/83
Local lCentPDV			:= IIf( ExistFunc("LjGetCPDV"), LjGetCPDV()[1] , .F. ) // Central de PDV

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Tratamento para e-Commerce      ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Local lECommerce        := SuperGetMV("MV_LJECOMM",,.F.) .AND. ( SL1->L1_ECFLAG == "1"  .OR. ( (ExistFunc("LJ862ECAuto") .And. LJ862ECAuto()) ) .OR. ;
																						( ExistFunc("Lj901Auto") .and. Lj901Auto() ) )
Local aXPgtos    	:= {}   //Salvar as parcelas calculadas para restaurar posteriormente.
Local lParceiros	:= 	SuperGetMv("MV_LJINDPA",,.F.) 		// Habilita comissão para parceiros que indicam a loja
Local luMovmeOrig	:= .F.									// Ler campo de controle do uMov.me
Local lLjNfPafEcf	:= LjNfPafEcf(SM0->M0_CGC)
Local lPDVPOS		:=  .F.
Local lSFinanc  	:= AliasIndic("MG8") .AND. SuperGetMV("MV_LJCSF",,.F.)	// Valida implementação do servico financeiro
Local cTitDocSai	:= ""
Local nRetLJ7087	:= 0												//Retorno PE LJ7087 - 0=Verifica emissao(padrão)/1=Emissão de CF ou NFC-e/2=Emissao de nota
Local lUseSat		:= LjUseSat()
Local lRent         := SuperGetMV("MV_LJRENT",,.F.)						//Habilita a exibicao da tela de rentabilidade na consulta de produtos.
Local lExibeEAN     := SuperGetMV("MV_LJEXEAN",,.F.)						//Habilita a exibicao do campo codigo de barras(EAN) no venda assistida ao selecionar um ao lado do codigo do produto
Local lMVLJLBNT		:= SuperGetMV("MV_LJLBNT",,0) > 0//Habilita Finaliza Venda - Vide doc:http://tdn.totvs.com.br/display/PROT/TUXK67_DT_Disponibilizar_Emissao_Nota_Fiscal_Interestadual_Venda_Assistida
Local cLJRESER 		:= SuperGetMV("MV_LJRESER ",,"1") //Controla como será realizada a reserva de produtos da venda. 1=Ao pressionar o botão F11; 2=Na gravação do orçamento; 3=Na gravação da venda.
Local lErroNFCe	 	:= .F.	//Sinaliza erro ao transmitir a NFC-e
Local lErroNFe	 	:= .F.	//Sinaliza erro ao transmitir a NF-e
Local lFRTECF13			:= ExistBlock("FRTECF13") 		// PE para indicar se o ECF faz o arredondamento (.T.) ou truncamento (.F.) dos valores.
Local nTamLQ_TPFRET	:= TamSx3("LQ_TPFRET")[1] 		// Tamanho do campo LQ_TPFRET
Local cTpFrete 		:= "" //Tipo do Frete
Local lECCia		:= SuperGetMV("MV_LJECOMM",,.F.) .AND. SuperGetMV("MV_LJECOMO",,.F.) .AND. ( SL1->((ColumnPos("L1_ECFLAG") > 0) .AND. (L1_ECFLAG == "1"))  .OR. (  ( ExistFunc("Lj901Auto") .and. Lj901Auto() ) ) )
Local nNFDesc		:= 0	//desconto recuperado da MATXFIS + desconto dado no total (quando orcamento e salvo)
Local aLj7CondPr	:= {}	//Parâmetros da rotina de Condição de Pagamento
Local nNum			:= 0	// Variavel responsavel por controle do F
Local aCamposPrc	:= {}	//Array responsavel por armazenar as posições do aPrcAuto
Local nScanPrc		:= 0	//Armazena posição do aScan aPrcAuto
Local nPosDescMn	:= 0	//Armazena posição do Desconto MultiNegociacao
Local lSTBArqPend	:= !lAutoExec .And. ExistFunc("STBArqPend") .And. !STBArqPend()
Local lVldArqSer	:= .T.
Local lIntegDef	:= If(Type("lAutoExec") == "L", lAutoExec, .F.) .And. FWHasEAI("LOJA701",, .T., .T.) .AND. Lj701GtInD() //Integracao via Mensagem Unica
Local lIntegHtl	:= lIntegDef .And. SuperGetMv("MV_INTHTL",, .F.)
Local cContaHtl	:= "" //Conta Hotel
Local aTefInteg	:= {} //Informacoes Tef Integracao Mensagem unica
Local nPosSLR		:= 0 //Posicao do campo na SLR
Local cBkReadVar    := Nil
Local nBkp          := 0
Local nI            := 0
Local nPosAE_MSBL   := SAE->(ColumnPos( "AE_MSBLQL" ) ) // Verifica se existe o campo AE_MSBLQL
Local cMNFormPg     := SuperGetMV("MV_LJMNFPG",,'') //Necessario para alimentar a variavel aAdmFinanc quando utilizada rotina de finalização em lote de orcamentos em ambiente NFCE
Local lAutomato := If(Type("lAutomatoX")<>"L",.F.,lAutomatoX)
//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
Local lEmitNfce	:= LjEmitNFCe()// Sinaliza se utiliza NFC-e
Local cNomeProg	:= Iif(lFtvdVer12,"FATA701","LOJA701") 	//Nome da Rotina

Default cFilContra	:= ""
Default aCabAuto	:= {}
Default aItAuto		:= {}
Default aPrcAuto	:= {}
Default lSalVen		:= .F.

//Variaveis utilizadas nos fontes de calculo de imposto localizado M460XIB2 e M460XIBP
Private aImpIB2		:={}

If cPaisLoc == "ARG" .And. ExistFunc("ACPOIMPARG")
	Private ACPOIMP := ACPOIMPARG()
EndIf

//Caso o usuario logado não tenha permissao de acesso a Rotina de Atendimento, é apresentada a mensagem a seguir, e a rotina é finalizada.
If !VerSenha(25) .And. (nOpc == 3)
	MsgStop(STR0378 + UsrRetName(__cUserId) + STR0379,STR0380,"STOP")//"Verifique as restrições de acesso(Cadastro de Usuário->Restrições de Acesso->Acessos) do usuário: " \\", referente a rotina de atendimento." \\"Acesso Negado!"
	Return Nil
EndIf

If cPaisLoc == "ARG" .And. SLQ->(ColumnPos("LQ_ADIC5")) > 0 .And. SLQ->(ColumnPos("LQ_ADIC61")) > 0
	nTamADIC5		:= TamSx3("LQ_ADIC5")[1] 		// Tamanho do campo LQ_ADIC5
	nTamADIC61		:= TamSx3("LQ_ADIC61")[1] 		// Tamanho do campo LQ_ADIC61
	nTamADIC62		:= TamSx3("LQ_ADIC62")[1] 		// Tamanho do campo LQ_ADIC62
	nTamADIC7		:= TamSx3("LQ_ADIC7")[1]
EndIf

If Type("oTef") <> "U"
	oTEF:aRETCARTAO := {}
	lTefPendCS := .F.
	oTEF:lTEFOk := .F.
EndIf

//Venda Offline nao permite utilizar NFCe
If lMvLjPdvPa .And. !lAutoExec .And. lEmitNfce .And. !lIsPafNfce	
	MsgStop(STR0420 + CRLF +; //"Identificado que o ambiente está configurado para Paf-ECF (Offline)"
			STR0421 + CRLF +; //"Não é possível utilizar NFCe neste ambiente"
			STR0422			) //"Verifique as configurações do cadastro de estação."
	
	Return .F.				
EndIf

LJ7DadosVL({1}) //Limpa dados PBM Funciona Card

//-------------------------------------------------------------------------
// Carrega as variaveis estaticas referente ao "Cartao Presente" (Gift Card).
//-------------------------------------------------------------------------
If ExistFunc("Lj7CP_OK") .And. Lj7CP_OK() //Verifica se permite utilizar a implementacao de Cartao Presente (Gift Card)
	Lj7CP_Load()
	If nOpc == 4 .And. Lj7CP_Ativ()
		//Verifica se tem Produto de Recarga de Cartao Presente (Gift Card)
		//Caso existir, nao permite finaliar a venda, pois a Recarga somente pode ser feita durante a venda no momento que lanca o produto na GetDado e por causa do TEF
		If Lj7VdIsRCP(SL1->L1_NUM)
			If !lAutoExec
				MsgStop(STR0352) //"Este orçamento possui recarga de Cartão Presente. Não é permitido finalizar a venda."
			Else
				Conout(STR0352) //"Este orçamento possui recarga de Cartão Presente. Não é permitido finalizar a venda."
			EndIf
			Return .F.
		EndIf
	EndIf
EndIf

If  (nOpc == 4)
    If  lECommerce
		If !lAutoExec
			MsgStop(STR0305)  //"Orçamento gerado pelo e-commerce! Não pode finalizar a venda!"
		Else
			Conout(STR0305)   //"Orçamento gerado pelo e-commerce! Não pode finalizar a venda!"
		EndIf
		Return(.F.)
    EndIf
ElseIf nOpc == 2 .AND. lECommerce .AND. !Empty(SL1->L1_ORCRES)   .AND.  !lAutoExec
	MsgInfo( STR0341 + SL1->L1_ORCRES)     //"As informações dos pagamentos do orçamento, referente a uma venda e-commerce, devem ser visualizadas no orçamento origem "
EndIf

If nOpc == 7
	If Lj7ValidAt()
		lAlterOrc := .T.
		nOpc      := 4
	Else
		Return(.F.)
	EndIf
EndIf

//³Release 11.5 - Cartao Fidelidade³
//³Limpar array de recarga de      ³
//³cartao fidelidade               ³
If ExistFunc( "LaFunhDelS")
	LaFunhDelS()
EndIf

If lMvLjPdvPa
	If !lAutoExec
		bSalOrc := {|| Alert(STR0149)} //"Nao e possivel gravar Orcamento no PDV"
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Limpa array de Kit de Produtos	³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
aProdKit := {}

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Limpa array dos produtos a fazer Solicitacao de compras 	 ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
//para ciashop não deve limpar a variavel de solicitação de compras pois a rotina é chamada após a reserva
If ExistFunc("LA590SetSC") .AND. AllTrim(Str(SuperGetMv("MV_LJGERSC",,1))) $ "2|3" .AND. !lECCia
	LA590SetSC()
Endif

//Atribuindo valor falso a variavel static lFreteAlt do fonte LOJA701A.PRW
SetFretAlt(.F.)

//Carrega as variaveis estaticas referente a "Recarga de Celular"
Lj7RCLoad()

//Vale Presente (Reinicia variavel de Controle)
If ExistFunc("Lj7VPNew") .And. Lj7VPNew()
	If nOpc == 4 .AND. !Lj7VPIsPrd(POSICIONE("SL2", 1,Xfilial("SL2") + SL1->L1_NUM ,"L2_PRODUTO"))
		Lj7VPVdaVP(2)//Indico que ja existe item e por esse motivo não podera incluir vales presentes / vale credito
	Else
		Lj7VPVdaVP(0)	
	EndIf
EndIf

//Reinicia varialveis Static do fonte do loja701B
If ExistFunc("Lj7BClean")
	Lj7BClean()
EndIf

//Limpa o vetor aRetLj7T que contem o backup do rodape da venda (utilizada na Regra Desconto Varejo)
If ExistFunc("LjSetLj7T")	//LOJA701B
	LjSetLj7T(0)
EndIf

If (lLjNfPafEcf .OR. (Len(aLeg) >= 1) .OR. (cPaisLoc == "ARG")) .AND. nOpc == 4
	If lLjNfPafEcf .OR. aLeg[1] .OR. (cPaisLoc == "ARG" .AND. nOpc == 4)
		If UPPER(SL1->L1_STORC) == "C"
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ "Orçamento cancelado. Não poderá ser impresso."  ### "Atenção"³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If !lAutoExec
				Alert(STR0118, STR0015)
			Else
				ConOut(STR0118)
				Help( " ", 1, "Help",, STR0118, 1, 0 )
			EndIf
			Return (.F.)
		EndIf
	EndIf
EndIf
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Define GetDados da tela de Venda Assistida, Os outros objetos³
//³ estao declarados como Local (Dialog, Enchoice, ListBox,      |
//| Panel 1, Panel 2)											 ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Private oGetVA
Private lpTPAbISS := ( SuperGetMV("MV_TPABISS",, "1") == "2" )

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Se for interface MDI redefine o tamanho da tela para evitar  ³
//³ o scroll horizontal e vertical                               ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If SetMDIChild()
	aSize1[5] := aSize1[5] - 12
	aSize1[3] := aSize1[5] / 2
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Define objetos que devem ser Private                         ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Private oDlgVA										// Contem a dialog principal
Private oPgtos										// Contem as parcelas de pagamento
Private oPgtosSint									// Contem as parcelas de pagamento sintetizadas
Private oDescCondPg									// Descricao da condicao de pagamento (qdo utilizada via SE4)
Private oCondPg

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Define variaveis Private para a rotina de reserva            ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Private cLojaLocal	:= ""							// Codigo (LJ_CODIGO) da loja local

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Define outras variaveis Private                              ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Private cTabPad 	:= SuperGetMV("MV_TABPAD")			// Tabela de preco padrao
Private aFontes		:= {}								// Array com os fontes a serem utilizados para exibicao da tela
Private aPosCpo		:= {}								// Contem posicao relativa dos campos do aCols
Private aPosCpoDet 	:= {}								// Contem posicao relativa dos campos do aColsDet (array de detalhes dos produtos)
Private aBotTB		:= {}								// Array com os botoes da toolbar
Private aTela[0][0],aGets[0]							// Variaveis para validacao da enchoice
Private	nMoedaCor	:= 1                                //Moeda da venda
Private lVisuSint	:= .T.								//Indica se a interface utilizará a forma de visualização sintetizada ou a antiga, evitando problemas com a metodologia anterior
Private aPgtos		:= { {Ctod(Space(8)),0,Space(2),{},NIL,NIL,NIL,If(lVisuSint,Space(nTamL4_FORMAID),Space(01)),Space(nTamL4_CHEQUEID),0} } // Array para o objeto oPgtos
Private aPgtosSint	:= { {Space(02),0,TransForm(0,PesqPict("SL4","L4_VALOR",,nMoedaCor)),If(lVisuSint,Space(nTamL4_FORMAID),Space(01)),Ctod(Space(8)),{},Space(nTamL4_CHEQUEID),0} } // Array para o objeto oPgtosSint
Private aAdmFinanc 	:= {}								// Array com as administradoras financeiras
Private nDecimais 	:= MsDecimais(nMoedaCor)			// Casas decimais que esta trabalhando o sistema
Private nTxMoeda    := 1                               // Taxa da moeda
Private cDescCondPg	:= Space(TamSX3("E4_DESCRI")[1])	// Descricao da condicao de pagamento (qdo utilizada via SE4)
Private bRefresh	:= {|| oGetVA:oBrowse:Refresh() }	// Bloco de codigo que sera chamado na funcao MafisRef (funcao fiscal)
Private aDesconto 	:= { 0, 0, 0 }						// Array para controle do desconto [1]-Tipo (1-Antes da cond.pg|2-Depois) [2]-%Desconto [3]-Vlr.Desconto
Private aAcrescimo	:= { 0, 0 }							// Array para controle do acrescimo [1]-Valor do acrescimo [2]-Percentual do acrescimo
Private nRotina 	:= nOpc 							// Variavel que indica qual a opcao selecionada no menu (aRotina) | 1-Pesquisar 2-Visualizar 3-Atendimento 4-Finaliza Venda
Private aColCustom  := {} 								// Coluna customizada no ListBox de Parcelas
Private lRecebe		:= .F.								// Variavel que indica que esta sendo efetuado recebimentos (LOJXREC)
Private lLayAway    := .F.                             // Indica se a venda corresponde a finalizacao de Lay-Away(POR|EUA)
Private aTitulo		:= {}									// Array com os titulos a serem recebidos (LOJXREC)
Private cOldTpFrete		:= ""							// Armazena o tipo de frete usado para gravar o orcamento
Private nNumUltIt   := 0						   		// Numero do ultimo item registrado no cupom.(Casos de retomada da venda Front Loja)
Private aPISCofCSL  := {}

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Definicao do array aTotais												³
//³ 															 			³
//³ Observacoes:		 													³
//³ 	1) Dimensao 4 x 4	 									 			³
//³ 	2) O tamanho maximo do titulo deve ser 15 caracteres	 			³
//³ 															 			³
//³ [Titulo]		[Valor]	[Objeto do valor]	[Picture]	[Objeto do SAY]	³
//³ [1] - Sub-total															³
//³ [2] - Desconto %													 	³
//³ [3] - Desconto $												 		³
//³ [4] - Total da venda											 		³
//³ [5] - Total das parcelas										 		³
//³ [6] - Troco             										 		³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Nao esquecer de passar o parametro de Moeda corrente na PesqPict³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lFtvdVer12
	Private aTotais	:= {{ STR0029	, 0, Nil, PesqPict("SL1", "L1_VLRTOT" ,,nMoedaCor), NIL},;  //"Sub-total + impostos"
						 	{STR0030	, 0, Nil, PesqPict("SL1", "L1_DESCNF" ,,nMoedaCor), NIL},;  //"Desconto %"
	 					 	{STR0031	, 0, Nil, PesqPict("SL1", "L1_DESCONT",,nMoedaCor), NIL},;  //"Desconto $"
	 					 	{STR0032	, 0, Nil, PesqPict("SL1", "L1_VLRTOT" ,,nMoedaCor), NIL},;  //"Total de Mercadorias"
	 					 	{STR0033	, 0, Nil, PesqPict("SL1", "L1_VLRTOT" ,,nMoedaCor), NIL},;  //"Total Parcelas"
	 					 	{STR0034	, 0, Nil, PesqPict("SL1", "L1_VLRTOT" ,,nMoedaCor), NIL},;  //"Troco"
	 					 	{STR0233	, 0, Nil, PesqPict("SL1", "L1_DESCONT",,nMoedaCor), NIL}}  //"Suframa"
Else
	Private aTotais	:= {{ STR0029	, 0, Nil, PesqPict("SL1", "L1_VLRTOT" ,,nMoedaCor), NIL},;  //"Sub-total + impostos"
					 	{STR0030	, 0, Nil, PesqPict("SL1", "L1_DESCNF" ,,nMoedaCor), NIL},;  //"Desconto %"
 					 	{STR0031	, 0, Nil, PesqPict("SL1", "L1_DESCONT",,nMoedaCor), NIL},;  //"Desconto $"
 					 	{STR0032	, 0, Nil, PesqPict("SL1", "L1_VLRTOT" ,,nMoedaCor), NIL},;  //"Total de Mercadorias"
 					 	{STR0033	, 0, Nil, PesqPict("SL1", "L1_VLRTOT" ,,nMoedaCor), NIL},;  //"Total Parcelas"
 					 	{STR0034	, 0, Nil, PesqPict("SL1", "L1_VLRTOT" ,,nMoedaCor), NIL},;   //"Troco"
 					 	{STR0382    , 0, Nil, PesqPict("SL2", "L2_QUANT"  ,,nMoedaCor), NIL}}   //"Qtde Volume"
EndIf

Private aRodape := {{"",NIL}}
Private bConsCredit := {|| (SA1->(DbSetOrder(1)),IIf(SA1->(DbSeek(xFilial("SA1")+M->LQ_CLIENTE+M->LQ_LOJA)),;
                           fConsWizard({	SA1->A1_NOME	, SA1->A1_PESSOA	, SA1->A1_NREDUZ	, SA1->A1_END,;
                           					SA1->A1_CEP		, SA1->A1_DDD		, SA1->A1_TEL		, SA1->A1_CGC,;
                           					SA1->A1_RG		, SA1->A1_DTNASC}),.T.))}

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Definicao do array aFuncoes												³
//³ 																		³
//³ Tem como objetivo definir TODAS as funcoes que estao disponiveis para 	³
//³ a interface de venda													³
//³ 															 			³
//³ Observacoes:		 													³
//³ 	1) Dimensao n x 8	 									 			³
//³ 															 			³
//³ Conteudo das colunas										 			³
//³ 															 			³
//³ [1] - Titulo para o menu										 		³
//³ [2] - Titulo para botao	(tip)											³
//³ [3] - Resource															³
//³ [4] - Funcao a ser executada 										 	³
//³ [5] - Aparece na toolbar lateral ? (TRUE / FALSE)						³
//³ [6] - Habilitada ? (TRUE / FALSE)					 					³
//³ [7] - Grupo	(1 - Gravacao, 2 - Detalhes, 3 - Estoque, 4 - Outros)       ³
//³ [8] - Tecla de atalho                                                   ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ ******************  I  M  P  O  R  T  A  N  T  E  ********************* ³
//³ A ordem dos itens do array aFuncoes nao pode ser alterados              ³
//³ Se for criada uma nova opcao, essa deverah ser criada por ultimo.       ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Se for lAlterOrc esta com a opção de alteracao de orc    ³
//³ entao a função de defpagto nao e chamada                ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If !lAlterOrc
	Private aFuncoes := {	{STR0035, STR0036, "SALVAR",	bSalOrc																																, .T., .T., 1, {VK_F4,   "F4"} },;		// "Como orcamento" ### "Gravar como orcamento"
							{STR0037, STR0038, "PEDIDO",	bSalVen																																, .T., .F., 1, {VK_F5,   "F5"} },;		// "Como venda"### "Gravar como venda"
							{STR0039, STR0039, "FINAL",		bSair																																, .T., .T., 1, {VK_F6,   "F6"} },;		// "Sair" ### "Sair"
							{STR0040, STR0041, "PRECO",		{|| IIf(Lj7SetKeys(), Lj7DefPag(.F., @oPanVA3, aPosObj4, oEncVA, nOpc, @lTefPendCS, @aTefBKPCS, @cAlterCond, NIL, @nVlrAcrsFi, Nil, Nil, @aDadosCNeg), nil)}	, .T., .T., 2, {VK_F7,   "F7"} },;		// "Pagamento" ### "Definir pagamentos"
							{STR0042, STR0043, "BMPVISUAL",	{|| IIf(Lj7SetKeys(), Lj7DetItem(nOpc, @lTefPendCS, @aTefBKPCS), nil) } 															, .T., .T., 2, {VK_F8,   "F8"} },;		// "Item" ### "Detalhar item"
							{STR0044, STR0045, "CARGA",		{|| IIf(Lj7SetKeys(), LJ7Frete(nOpc,@nVlrAcrsFi), nil)	}																						, .T., .T., 2, {VK_F9,   "F9"} },;		// "Frete" ### "Detalhar frete"
							{STR0046, STR0047, "HISTORIC",	{|| IIf(Lj7SetKeys(), Lj7DetCli( M->LQ_CLIENTE ), nil) }																			, .F., .T., 2, {VK_F10, "F10"} },;		// "Cliente" ### "Detalhar cliente"
							{STR0048, STR0049, NIL,			{|| IIf(Lj7SetKeys() .AND. nOpc<>2 .AND. cLJRESER=="1",LJ7BtnRes( 1 ), nil) }																			, .F., .T., 3, {VK_F11, "F11"} },;		// "Efetuar reserva" ### "Reservar produto"
							{STR0050, STR0051, NIL,			{|| IIf(Lj7SetKeys() .AND. nOpc<>2,LJ7BtnRes( 2 ), nil) }																			, .F., .T., 3, {VK_F12, "F12"} },;		// "Consultar reserva" ### "Consultar reserva de produto"
							{STR0052, STR0053, NIL,			{|| IIf(Lj7SetKeys(), LJ7Estoque(), nil) }																							, .F., .T., 3, {1, "Ctrl+A"} },;		// "Consultar estoque" ### "Consultar estoque de produto"
							{STR0054, STR0054, "BUDGETY",	{|| IIf(Lj7SetKeys() .AND. nOpc<>2,Lj7VldDesc( oPanVA3 ), nil) }																	, .T., .T., 2, {2, "Ctrl+B"} },;		// "Desconto" ### "Desconto"
							{STR0055, STR0055, "PRECO",		{|| IIf(Lj7SetKeys() .AND. nOpc<>2,Lj7Tabela(), nil) }																				, .T., .T., 2, {3, "Ctrl+C"} },;		// "Tabela de Preços" ### "Tabela de Preços"
							{STR0072, STR0072, "SALARIOS",	{|| IIf(Lj7SetKeys() .AND. LJ7Recebe(nOpc, @oTitulo),;
				 											Lj7DefPag(.F., @oPanVA3	, aPosObj4, oEncVA, nOpc, @lTefPendCS, @aTefBKPCS, @cAlterCond, NIL, @nVlrAcrsFi, Nil, Nil, @aDadosCNeg), nil) }					, .T., .T., 4, {4, "Ctrl+D"} },;		// "Recebimentos" ### "Recebimentos"
							{STR0115, STR0115, "CHAVE2",	{|| IIf(Lj7SetKeys(), LJ7CONSEL( nOpc, SuperGetMV("MV_TEFGRT") ), nil) } 															, .T., .T., 4, {5, "Ctrl+E"}  }}		// "Consulta Eletronica" ### "Consulta Eletronica"
Else
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³O fechamento da venda nao pode ser feito dentro da alteracao³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	Private aFuncoes := {	{STR0035, STR0036, "SALVAR",	bSalOrcAl																																, .T., .T., 1, {VK_F4,   "F4"} },;		// "Como orcamento" ### "Gravar como orcamento"
							{STR0037, STR0038, "PEDIDO",	{||}																																, .T., .F., 1, {VK_F5,   "F5"} },;		// "Como venda"### "Gravar como venda"
							{STR0039, STR0039, "FINAL",		bSair																																, .T., .T., 1, {VK_F6,   "F6"} },;		// "Sair" ### "Sair"
							{STR0040, STR0041, "PRECO",		{||}	, .T., .T., 2, {VK_F7,   "F7"} },;		// "Pagamento" ### "Definir pagamentos"												{STR0042, STR0043, "BMPVISUAL",	{|| IIf(Lj7SetKeys(), Lj7DetItem(nOpc, @lTefPendCS, @aTefBKPCS), nil) } 															, .T., .T., 2, {VK_F8,   "F8"} },;		// "Item" ### "Detalhar item"
							{STR0042, STR0043, "BMPVISUAL",	{|| IIf(Lj7SetKeys(), Lj7DetItem(nOpc, @lTefPendCS, @aTefBKPCS), nil) } 															, .T., .T., 2, {VK_F8,   "F8"} },;		// "Item" ### "Detalhar item"
							{STR0044, STR0045, "CARGA",		{|| IIf(Lj7SetKeys(), LJ7Frete(nOpc,@nVlrAcrsFi), nil)	}																						, .T., .T., 2, {VK_F9,   "F9"} },;		// "Frete" ### "Detalhar frete"
							{STR0046, STR0047, "HISTORIC",	{|| IIf(Lj7SetKeys(), Lj7DetCli( M->LQ_CLIENTE ), nil) }																			, .F., .T., 2, {VK_F10, "F10"} },;		// "Cliente" ### "Detalhar cliente"
							{STR0048, STR0049, NIL,			{|| IIf(Lj7SetKeys() .AND. nOpc<>2 .AND. cLJRESER=="1",LJ7BtnRes( 1 ), nil) }																			, .F., .T., 3, {VK_F11, "F11"} },;		// "Efetuar reserva" ### "Reservar produto"
							{STR0050, STR0051, NIL,			{|| IIf(Lj7SetKeys() .AND. nOpc<>2,LJ7BtnRes( 2 ), nil) }																			, .F., .T., 3, {VK_F12, "F12"} },;		// "Consultar reserva" ### "Consultar reserva de produto"
							{STR0052, STR0053, NIL,			{|| IIf(Lj7SetKeys(), LJ7Estoque(), nil) }																							, .F., .T., 3, {1, "Ctrl+A"} },;		// "Consultar estoque" ### "Consultar estoque de produto"
							{STR0054, STR0054, "BUDGETY",	{|| IIf(Lj7SetKeys() .AND. nOpc<>2,Lj7VldDesc( oPanVA3 ), nil) }																	, .T., .T., 2, {2, "Ctrl+B"} },;		// "Desconto" ### "Desconto"
							{STR0055, STR0055, "PRECO",		{|| IIf(Lj7SetKeys() .AND. nOpc<>2,Lj7Tabela(), nil) }																				, .T., .T., 2, {3, "Ctrl+C"} },;		// "Tabela de Preços" ### "Tabela de Preços"
							{STR0072, STR0072, "SALARIOS",	{|| IIf(Lj7SetKeys() .AND. LJ7Recebe(nOpc, @oTitulo),;
					 										NIL, nil) }	, .T., .T., 4, {4, "Ctrl+D"} },;		// "Recebimentos" ### "Recebimentos"
							{STR0115, STR0115, "CHAVE2",	{|| IIf(Lj7SetKeys(), LJ7CONSEL( nOpc, SuperGetMV("MV_TEFGRT") ), nil) } 															, .T., .T., 4, {5, "Ctrl+E"}  }}		// "Consulta Eletronica" ### "Consulta Eletronica"
EndIf


//Zera a variável de controle do troco por forma de pagamento

//Zera a forma de pagamento que permite troco
If ExistFunc("Lj7SetTrcForm")
	Lj7SetTrcForm("")
EndIf


//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Verifica se o processo de Lista de Presentes      ³
//³ esta aplicaso, caso sim, habilita o botao	     ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lUsaLstPre
	nAtalho++
	aAtalho  := Lj7Atalho(nAtalho)
	AAdd(aFuncoes,  {STR0225,STR0226,STR0227,{|| IIF(Lj7SetKeys(),Lj7BtnLista(), nil) }, .F., .T., 4,aAtalho})   //// "Consulta Lista", "Consulta Lista de Presentes", "NOTE"
EndIf

//Se utiliza servico financeiro, reinicia variavel de controle vinculo produto
If lSFinanc .AND.ExistFunc("Lj7SetServ")
	Lj7SetServ(.T.)
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Release 11.5 - Chile - F1CHI                           ³
//³Alteracao da PICTURE do campo L1_DESCNF, por ser o     ³
//³unico no array aTotais que trabalha com decimais, assim³
//³ignorando a variavel nMoedaCor.                        ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If cPaisLoc == "CHI"
	aTotais[2][4]:= PesqPict("SL1", "L1_DESCNF")
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Define a moeda padrao a ser utilizada para a venda³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If cPaisLoc <> "BRA"
	nMoedaCor	:= SuperGetMV("MV_LJMDORC",,1)
	nTxMoeda	:= RecMoeda(dDataBase,nMoedaCor)
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Caso seja executado por EXECAUTO nao tem objeto para ser atualizado³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lAutoExec
	bRefresh	:= {|| .T. }
EndIf
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Se a pre-venda estiver configurada, nao deve permitir   ³
//³descontos na alteracao do orcamento e PAF-ECF           ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lLjNfPafEcf .AND. !lFtvdVer12
	If lFiscal .AND. nOpc == 4 .AND. LjMPreVend(SM0->M0_CGC)
		aFuncoes[11][4] := {||}
	EndIf

	If lMvLjPdvPa
		aFuncoes[6][4] 		:= {||}
		aFuncoes[8][4] 		:= {||}
		aFuncoes[14][4] 	:= {||}
	EndIf
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Nao deve mais permitir salvar como venda, caso nao seja ³
	//³um PDV conforme o projeto PAF-ECF SIGA OFF LINE         ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If !lMvLjPdvPa .AND. !lMVLJLBNT
		aFuncoes[13][4] 	:= {||} 	//Nao permite efetuar recebimentos quando nao for PDV
		aDel(aFuncoes,2)
		aSize(aFuncoes,Len(aFuncoes)-1)
	EndIf
EndIf

If lCatProd .AND. !lAutoExec
    //Funcionalidade para apenas TOP
	#IFDEF TOP
		nAtalho++
		aAtalho  := Lj7Atalho(nAtalho)
		AAdd(aFuncoes, {STR0178, STR0178 , "SDUPROPR", {|| If(nOpc<>2, LjMsgRun(STR0177,,{|| Lj7ConProCat(1, aCpoGDa) } ), Nil) }, .T., .T., 4, aAtalho} ) //Aguarde. Consulta....##"Pesquisa Produtos na Categoria de Produtos" ##"Pesquisa Produtos na Categoria de Produtos"

		nAtalho++
		aAtalho  := Lj7Atalho(nAtalho)
		AAdd(aFuncoes, {STR0179, STR0179, "PMSRELA", {|| If(nOpc<>2, LjMsgRun(STR0177,,{|| Lj7ConProCat(2, aCpoGDa) } ), Nil) }, .T., .T., 4, aAtalho} ) //Aguarde. Consulta.... ##"Pesquisa Produtos Equivalentes" ##"Pesquisa Produtos Equivalentes"
	#ENDIF
EndIf

If HasTemplate("DRO")
	If SuperGetMv("MV_PLSATIV",.F.,.F.) .AND. SuperGetMv("MV_PLSDRO",.F.,.T.)
		DbSelectArea("BSP")
		BSP->(DbSetOrder(1))
		If SuperGetMv("MV_PLSLDR",.F.,"") == ""
			If !lAutoExec
				Aviso(STR0136,STR0137,{"Ok"},2) //"INTEGRAÇÃO PLS"##"Para a Integração com PLS necessita criar o Parametro 'MV_PLSLDR' para informar o Tipo de Lançamento no Módulo Plano de Saúde"
			Else
				Conout(STR0136 + " - " + STR0137)
				Help( " ", 1, "Help",, STR0136 + " - " + STR0137, 1, 0 )
			Endif
			Return
		Else
			 If !BSP->(DbSeek(xFilial("BSP")+SuperGetMv("MV_PLSLDR",.F.)))
			 	If !lAutoExec
	 	   			Aviso(STR0136,STR0138,{"Ok"},2)//"INTEGRAÇÃO PLS"##"Para a Integração com PLS necessita criar um Tipo de Lançamento no Módulo Plano de Saúde de acordo com informado no parametro 'MV_PLSLDR'"
	 	   		Else
	 	   			ConOut(STR0136 + " - " + STR0138)
	 	   			Help( " ", 1, "Help",, STR0136 + " - " + STR0138, 1, 0 )
	 	   		EndIf
	   		 	Return
	   		 Else
	   		     If BSP->BSP_TIPSER <> "1"
	   		     	If !lAutoExec
	   		     		Aviso(STR0136,STR0139,{"Ok"},2)//"INTEGRAÇÃO PLS" ##"Para a Integração com PLS o Tipo de Lançamento no Módulo Plano de Saúde informado no parametro 'MV_PLSLDR' tem quer ser débito"
	   		     	Else
	   		     		ConOut(STR0136 + " - " + STR0139)
	   		     		Help( " ", 1, "Help",, STR0136 + " - " + STR0139, 1, 0 )
	   		     	EndIf
	   		 		Return
	   		     Endif
	   		 Endif
		Endif
	Endif
Endif

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Soh define o tamanho do SX3 caso o campo exista³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lVisuSint
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Tamanho do campo L4_FORMAID³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	nTamL4_FORMAID  	:= TamSX3("L4_FORMAID")[1]
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Inclui a opcao "Fator Financeiro" no menu Outros            ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
nAtalho++
aAtalho  := Lj7Atalho(nAtalho)
AAdd(aFuncoes, {STR0105, STR0105, NIL, {|| If(nOpc<>2, Lj7Fator(@oPanVA3,@lUsouFator,@nFator,@cAdmFator), Nil) }, .F., .T., 4, aAtalho} ) //"Financiamento" ## "Financiamento"

If !lMvLjPdvPa
    nAtalho++
    aAtalho  := Lj7Atalho(nAtalho)
	AADD( aFuncoes,	 {STR0112, STR0112, "reload",;
	{|| If(FUNNAME() == cNomeProg, Loja720(	M->LQ_CLIENTE, M->LQ_LOJA, .T., @aDocDev,;
												nOpc, oPanVA3:lVisibleControl ),.F.) }, .T., .T., 4, aAtalho })	//"Troca de Mercadorias" ### "Troca de Mercadorias"
EndIf

If (cPaisLoc == "BRA" .And. ( !lLjNfPafEcf .Or.  (lLjNfPafEcf .And. lMvLjPdvPa) )) .Or. ( cPaisLoc $ "COL|CHI" )
	nAtalho++
	aAtalho  := Lj7Atalho(nAtalho)
	AADD( aFuncoes,	 {STR0170, STR0170, "SIMULACAO",	{|| Fr271D050(1)}, .F., .T., 4, aAtalho })	 //"Sangria" ### "Sangria"

	nAtalho++
	aAtalho  := Lj7Atalho(nAtalho)
	AADD( aFuncoes,	 {STR0171, STR0171, "simulacao",	{|| Fr271D050(2)}, .F., .T., 4, aAtalho }) //"Suprimento" ### "Suprimento"
EndIf

/* Inclui o botao Menu Fiscal apenas se a nova funcao existir no repositorio. */
If lLjNfPafEcf .AND. lMvLjPdvPa
	nAtalho++
    aAtalho  := Lj7Atalho(nAtalho)
	AADD( aFuncoes,	 {STR0163, STR0163, "historic",	{|| STBMenFis(.T.,.F.)}, .T., .T., 4, aAtalho })	//"Menu Fiscal" ### "Menu Fiscal"

    nAtalho++
    aAtalho  := Lj7Atalho(nAtalho)
	AADD( aFuncoes,	 {STR0172, STR0172, "impressao",	{|| Loja160(), oDlgVA:End()}, .F., .T., 4, aAtalho }) //"Reducao Z" ### "Reducao Z"

	nAtalho++
	aAtalho  := Lj7Atalho(nAtalho)
	AAdd(aFuncoes, {STR0173  ,  STR0173    , NIL,     {|| LJMsgRun(STR0174,,{|| Lj7CaUlCup()}) }, .F., .T., 4, aAtalho} ) //"Cancelamento" ## "Cancelamento"

	//Opcao para importar orcamento quando ambiente PAF-ECF
	If HasTemplate("PCL") .AND. ExistTemplate("TpPclImpLeg")
		nAtalho++
		aAtalho  := Lj7Atalho(nAtalho)
		AAdd(aFuncoes, {STR0234,STR0234, NIL,{|| T_TpPclImpLeg()}, .T., .T., 4, aAtalho })	//"Abastecimento"
	EndIf
EndIf

If cPaisLoc <> "BRA"
	nAtalho++
	aAtalho := Lj7Atalho(nAtalho)
	Aadd(aFuncoes,{STR0083,STR0083,"EDIT",{|| If(nOpc<>2,Lj7Moeda(),Nil)}, .T., .T.,2, aAtalho})  //"Moeda"###"Moeda"
	If cPaisLoc $ "POR|EUA|MEX|COL"
		nAtalho++
		aAtalho := Lj7Atalho(nAtalho)
		Aadd(aFuncoes,{STR0084,STR0084, "AUTOM",	{|| If(nOpc<>2,Lj7LayAway(aCpoGDaDet),Nil) }, .T., .T., 2, aAtalho})   // "Lay-Away"### "Lay-Away"
	EndIf
	aPgtos := { {Ctod(Space(8)),0,Space(3),{},NIL,nMoedaCor,Ctod(Space(8)),If(lVisuSint,Space(nTamL4_FORMAID),Space(01)),Space(nTamL4_CHEQUEID),0} }
EndIf

If CrdxInt()
	nAtalho++
	aAtalho := Lj7Atalho(nAtalho)
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³"Cliente(CRD)","Selecionar cliente"³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	AAdd( aFuncoes,{STR0098,STR0099,"POSCLI",{|| If(nOpc<>2,Lj7CliCRD(),Nil)}, .T., .T., 4, aAtalho} )
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Inicializa o array aCrdCliente³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	Lj7SetCRDClie(.T.)

	nAtalho++
	aAtalho := Lj7Atalho(nAtalho)
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³"Credito","Analisar credito"	³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	AAdd( aFuncoes,{STR0096,STR0097,"SIMULACAO",{|| If(nOpc<>2,Lj7CRDAval(nOpc),Nil)}, .T., .T., 4, aAtalho} )
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Se houver integracao com cenario de vendas, exibe o botao³
//³para consulta de bonificacao                             ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lCenVenda
	nAtalho++
	aAtalho := Lj7Atalho(nAtalho)
	AAdd(aFuncoes,{STR0144,STR0145,"BONUS",{||LjConBonus()},.T.,.T.,4,aAtalho}) //"Bônus"###"Exibe produtos bonificados para a venda atual"
EndIf
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Inclui a opcao Turno            ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lUsaTurno
	nAtalho++
	aAtalho  := Lj7Atalho(nAtalho)
	AAdd(aFuncoes, {STR0180 , STR0180 , "CLOCK01", {|| If(nOpc<>2, Lj7Turno(), Nil) }, .T., .T., 4, aAtalho} ) //"Periodo de Entrega
EndIf

If lCatProd .AND. !lAutoExec
    //Funcionalidade para apenas TOP
	#IFDEF TOP
	   	nAtalho++
		aAtalho  := Lj7Atalho(nAtalho)
		AAdd(aFuncoes, {STR0209, STR0209, "SDURECALL", {|| If(nOpc<>2, LjMsgRun(STR0177,,{|| Lj7SugVend(aCpoGDa,.T.,NIL,1) } ), Nil) }, .T., .T., 4, aAtalho} ) //Aguarde. Consulta.... ##"Sugestao de vendas"
	#ENDIF
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Inclui a opcao midia no menu lateral				        ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If ExistFunc("LjxGetMid") .AND. AllTrim(Str(SuperGetMv("MV_LJRGMID",,0))) $ "1|2"
	nAtalho++
	aAtalho  := Lj7Atalho(nAtalho)
	AAdd(aFuncoes, {STR0202, STR0202, "OBJETIVO", {|| M->LQ_MIDIA:= LjxGetMid(M->LQ_MIDIA)}, .T., .T., 4, aAtalho} ) // Midia
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Adiciona Botao de Perfil da Entidade                                                ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If ExistFunc("TK010isPerfil") .AND. TK010isPerfil()
	nAtalho++
	aAtalho  := Lj7Atalho(nAtalho)
	AAdd(aFuncoes, {STR0291 , STR0291 , "GRAF2D", {|| Iif(Empty(M->LQ_CLIENTE) .OR. Empty(M->LQ_LOJA),; //"Perfil do Cliente"
		 MsgAlert(STR0292),; //"Preencha o Cliente/Loja."
		 TK010Con(,,,,,"SA1",M->LQ_CLIENTE+M->LQ_LOJA)) }, .T., .T., 4, aAtalho} )
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Se a configuracao de "Recarga de Celular" estiver ativa, ³
//³exibe a opcao de "Recarga de Celular".                   ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If Lj7RCAtiva() .AND. Iif(lMvLjPdvPa, !Empty(LjGetStation("WSSRV")), .T.) .AND. ( oTef:lTemPinPad .OR. ( FindFunction("LjTEFRCSPin") .AND. LjTEFRCSPin() ) )
	nAtalho++
	aAtalho  := Lj7Atalho(nAtalho)
	AAdd(aFuncoes,{STR0285,STR0285,"TK_FONE",{|| If(nOpc==3,oTef:RecargaNFiscal(),MsgStop("Somente é possível efetuar recarga de celular no modo Atendimento.")) },.T.,.T.,4,aAtalho}) //"Recarga de celular"
EndIf

//Planilha Financeira
If ExistFunc("LjFunDRent") .AND. ExistFunc("Lj701MgV") .AND. ExistFunc("PesqCliGru") .AND. lRent
	If AliasIndic("AIH") .AND. AliasIndic("AII")
		nAtalho++
		aAtalho  := Lj7Atalho(nAtalho)
		aAdd(aFuncoes, { STR0324, STR0324, nil, {|| LjFunDRent(nOpc) } , .T., .T., 4, aAtalho }   ) 	//"Consulta Rentabilidade"
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Integracao com Financial Service       ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lUsaIntFS == NIL
	lUsaIntFS	:= SuperGetMV("MV_LJINTFS",,.F.) .And. LjUpd90Ok(, !IsBlind())
EndIf
If lUsaIntFS
	nAtalho++
	aAtalho  := Lj7Atalho(nAtalho)
	aAdd(aFuncoes, { STR0272, STR0272, "SUMARIO", {|| IIF(!Empty(SL1->L1_IFSCDM2), Aviso(STR0274, MSMM(SL1->L1_IFSCDM2,255), {STR0028}),.T.) } , .T., .T., 4, aAtalho }   ) //"Mens Analise Credito"#"Mens Analise Credito"#"Mensagem Análise de Crédito"#OK
EndIf

//RFID
If ExistFunc("LJRFPesqProd") .AND. SuperGetMv("MV_RFID",,.F.) .AND. SLG->(FieldPos("LG_RFID") > 0)  .AND. LJGetStation("RFID") == "1"
	nAtalho++
	aAtalho  := Lj7Atalho(nAtalho)
	aAdd(aFuncoes, { STR0346 + " - " + STR0347 , STR0346 + " - " + STR0347, nil, {|| MsgRun( STR0350 ,'',{|| LJRFPesqProd() }) } , .T., .T., 4, aAtalho }   ) 	//"RFID" " - " "Leitura de Itens" "Aquarde, Realizando leitura de Itens RFID. "
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Recarga de Cartao Presente (Gift Card) ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
//Verifica se permite utilizar a implementacao de Cartao Presente (Gift Card)
If ExistFunc("Lj7CP_OK") .And. Lj7CP_OK() .And. Lj7CP_Ativ()
	nAtalho++
	aAtalho  := Lj7Atalho(nAtalho)
	AAdd(aFuncoes,{STR0318,STR0318,"SOLICITA",{|| If(nOpc==3,oTef:CartaoPresenteGiftCard("OCP"),MsgStop(STR0319)) },.T.,.T.,4,aAtalho}) //"Cartão Presente (Gift Card)" ### "Somente é possível efetuar recarga de Cartao Presente no modo Atendimento."
EndIf

//PBM Funcional Card
If ExistTemplate("DROVLGet")
	nAtalho++
	aAtalho  := Lj7Atalho(nAtalho)
	AAdd(aFuncoes,{STR0423,STR0423,"CONSULTA",{|| T_DROVLGet( 560 ) },.T.,.T.,4,aAtalho}) //"PBM Funcional Card" 
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Chamada da funcao LJ7016 para Fidelizacao (CRDXFUNE)           ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If ExistBlock( "LJ7016" ) .AND. !lFtvdVer12
	aFunc :=ExecBlock( "LJ7016", .F., .F., {nOpc, nAtalho} )
	If ValType( aFunc ) == "A"
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Todas as configuracoes de outros devem ir para a pasta "Outros"³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		For nX := 1 to Len( aFunc )
			AAdd( aFuncoes, aFunc[nX] )
		Next nX
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Chamada da funcao FTVD7016 para Fidelizacao (CRDXFUNE)           ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If ExistBlock( "FTVD7016" ) .AND. lFtvdVer12
	aFunc := ExecBlock( "FTVD7016", .F., .F., {nOpc, nAtalho} )
	If ValType( aFunc ) == "A"
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Todas as configuracoes de outros devem ir para a pasta "Outros"³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		For nX := 1 to Len( aFunc )
			AAdd( aFuncoes, aFunc[nX] )
		Next nX
	EndIf
EndIf
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Ponto de Entrada de Templates para customizacao da barra aFuncoes        ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If ExistTemplate( "LJ7016" ) .AND. !lFtvdVer12
	aFuncTpl := ExecTemplate( "LJ7016", .F., .F., {nOpc, nAtalho} )
	If ValType( aFuncTpl ) == "A"
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Todas as configuracoes de outros devem ir para a pasta "Outros"³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		For nX := 1 to Len( aFuncTpl )
			AAdd( aFuncoes, aFuncTpl[nX] )
		Next nX
	EndIf
EndIf
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Ponto de Entrada de Templates para customizacao da barra aFuncoes        ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If ExistTemplate( "FTVD7016" ) .AND. lFtvdVer12
	aFuncTpl := ExecTemplate( "FTVD7016", .F., .F., {nOpc, nAtalho} )

	If ValType( aFuncTpl ) == "A"

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Todas as configuracoes de outros devem ir para a pasta "Outros"³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		For nX := 1 to Len( aFuncTpl )
			AAdd( aFuncoes, aFuncTpl[nX] )
		Next nX
	EndIf
EndIf
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Ponto de entrada para validar o acesso a tela de atendimento da venda³
//³ Se retornar falso, volta para a MBrowse.                             ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If ExistBlock( "LJ7032" ) .AND. !lFtvdVer12
	lContAtend := ExecBlock( "LJ7032", .F., .F., { nOpc } )
	If ValType( lContAtend ) == "L" .AND. !lContAtend
		Return Nil
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Ponto de entrada para validar o acesso a tela de atendimento da venda³
//³ Se retornar falso, volta para a MBrowse.                             ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If ExistBlock( "FTVD7032" ) .AND. lFtvdVer12
	lContAtend := ExecBlock( "FTVD7032", .F., .F., { nOpc } )
	If ValType( lContAtend ) == "L" .AND. !lContAtend
		Return Nil
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Objetos aCols    ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Private aHeader[0], aCols
Private aColsDet 	:= {}		// Variaveis que irao conter os detalhes dos produtos
Private aHeaderDet 	:= {} 		// Variaveis que irao conter os detalhes dos produtos

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Objetos TEF      ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Private nValorBase   := 0
Private nEntrada     := 0
Private aTefDados    := {}
Private aParcTef     := {}
Private aTefMult     := {}
Private cGaranch     := ""
Private aCartaoMH    := {}

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Variaveis utilizadas pela NCC ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If ( Type("nNCCUsada") == "U" )
	Private aNCCItens  := {}
	Private nNCCUsada  := 0
	Private nNCCGerada := 0
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Variaveis utilizadas no SIGAPHOTO ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If nModulo == 72
	Private lGradProd := .F.
	Private aBalcItens:= {}
EndIf

If !lAutoExec
	lVldArqSer := LjVldSerie()
	If (!lLjNfPafEcf .And. !lVldArqSer) .Or.;
	 	(lLjNfPafEcf .And. lFiscal .And. (lSTBArqPend .Or. !lVldArqSer) )
	 	
		If lSTBArqPend
			MsgAlert(STR0435) //"Existem arquivos de XML pendentes de envio, acesso a rotina de venda não permitido"
	 	EndIf
	 	
		Return .F.
	EndIf
EndIf

If cPaisLoc <> "BRA"
   	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
   	//³ Variaveis utilizadas para Impostos Variaveis ³
   	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
   	Private nVlrImpDisc  := 0  //Total dos impostos discriminados
   	Private aImpsSL1  := {}
   	Private aImpsSL2  := {}
   	Private aTotImpsV := {}
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³	O array aDadosJur armazena os resultados do calculo dos juros ou desconto      ³
	//³	financeiro sendo que o mesmo eh valorizado na funcao Lj010RecVB, que se        ³
	//³	encontra no Loja010c.prw                                                       ³
	//³                                                                                ³
	//³	Descricao do Array                                                             ³
	//³	aDadosJur[1] => Total do acrescimo                                             ³
	//³	aDadosJur[2] => Valor Liquido da Venda                                         ³
	//³	aDadosJur[3] => Valor Base da Venda                                            ³
	//³	aDadosJur[4] => Valor total dos impostos                                       ³
	//³	aDadosJur[5] => Total de desconto                                              ³
	//³	aDadosJur[6] => Valor anterior do imposto                                      ³
	//³	aDadosJur[7] => Taxa de juros			                                       ³
	//³	aDadosJur[8] => Percentual de desconto                                         ³
	//³	aDadosJur[9] => Valor do desconto financeiro                                   ³
	//³	                                                                               ³
	//³	                                                                               ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
   	Private aDadosJur := {0,0,0,0,0,0,0,0,0}
   	Private aMoedas   := {}
  	Private aTroco    := {0,0,0,0,0}
    Private cSimbCheq := AllTrim(MVCHEQUE)
    Private oLBBaixa //Objeto utilizado na rotina de troco localizada...
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Cria os tipos de titulo, correspondentes as moedas, no arquivo SX5...³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
   	For nX := 1	To MoedFin()
    	If(!(Empty(SuperGetMV("MV_MOEDA"+Ltrim(STR(nX))))))
			LjCriaSimb(nX)
      	EndIf
   	Next nX
EndIf
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Verifica se o registro esta sendo utilizado                             ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If nOpc == 4 .And. !IsInCallStack("LjNFCeLot")
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Cria arquivo txt para semafaro, para não permitir finalizar  ³
	//³ dois orcamento ao mesmo tempo, nome do arquivo:              ³
	//³ FILIAL+ORCAMENTO.CAIXA                                       ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If !Lj7XSL1('C')
		Return .F.
	EndIf
	If !SoftLock(cAlias)
		Return .F.
	EndIf
EndIf

//³ Verifica qual a opcao selecionada e valida se pode ou nao entrar na     ³
//³ rotina. Nao permitir acessar finalizacao de venda se jah existe um      ³
//³ documento fiscal atrelado ao orcamento                                  ³
If nOpc == 4 .AND. (!Empty(SL1->L1_DOC) .OR. !Empty(SL1->L1_DOCPED) .OR. !Empty(SL1->L1_PEDRES) ) .AND. !lAlterOrc .AND.  !ALLTRIM(SL1->L1_NSO) == "P3"
	If !lAutoExec
		Aviso( STR0019, STR0071, {STR0028} )  // "Atenção" ### "Esse orçamento já foi finalizado." ### "Ok"
	Else
		ConOut(STR0071)
		Help( " ", 1, "Help",, STR0071, 1, 0 )
	EndIf

	//Ajusto o L1_SITUA que em determinados casos não volta e isso impede que a rotina de recuperação de venda execute corretamente
	If	SL1->(ColumnPos("L1_KEYNFCE")) > 0 .And. SL1->(ColumnPos("L1_SERSAT")) > 0 .And.;
		!Empty(AllTrim(SL1->L1_SERSAT)) .And. !Empty(AllTrim(SL1->L1_KEYNFCE))
		
		RecLock("SL1",.F.)
		REPLACE SL1->L1_SITUA WITH "OK"
		SL1->(MsUnlock())
	EndIf
	
	Lj7XSL1('D')
	Return .F.
EndIf

//PAF-ECF: Não permite alteração de DAV quando já realizou a impresão
If nOpc == 4 .AND. lLjNfPafEcf .AND. !lMvLjPdvPa .AND. !lPreVenda .AND.;
  !Empty(SL1->L1_COODAV)  .AND. !lFtvdVer12

	If !lAutoExec
		MsgStop(STR0283)  //"Conforme previsto no Resquisito VI(ATO COTEPE/ICMS 0608), é vedado a alteração do DAV já impresso."
	Else
		ConOut(STR0283)  //"Conforme previsto no Resquisito VI(ATO COTEPE/ICMS 0608), é vedado a alteração do DAV já impresso."
		Help( " ", 1, "Help",, STR0283, 1, 0 )
	EndIf
	Lj7XSL1('D')
	Return .F.
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Verifica a data de validade do orcamento. Nao permite finalizar a venda ³
//³ se o orcamento jah estiver vencido                                      ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If (nOpc == 4 .Or. nOpc == 5) .AND. Empty(Trim( SL1->L1_FILRES+SL1->L1_ORCRES )) .AND. SL1->L1_DTLIM < dDatabase .AND. SL1->L1_SITUA  <> "P3" 
	If !lAutoExec
		Help( "", 1, "DTVENCIDO" )
	Else
		ConOut(STR0236)		// "Orcamento Vencido"
		Help( " ", 1, "Help",, STR0236, 1, 0 )
	EndIf
	Lj7XSL1('D')
	Return .F.
EndIf

/*
Verifica se um Orçamento já Finalizado (Orçamento Filho) que contém apenas itens de GE (Garantia Estendida) 
ou SF (Serviços Financeiros) e caso seja não permite finalizar a venda, pois já foi finalizada.
*/
If nOpc == 4 .AND. Empty(Trim( SL1->L1_DOC+SL1->L1_RESERVA )) .AND. SL1->L1_TIPO == "P"
	If !lAutoExec
		Aviso( STR0019, STR0071, {STR0028} )  // "Atenção" ### "Esse orçamento já foi finalizado." ### "Ok"
	Else
		ConOut(STR0071)
		Help( " ", 1, "Help",, STR0071, 1, 0 )
	EndIf
	
	Lj7XSL1('D')
	Return .F.
EndIf
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Verifica se o usuario eh um caixa para poder efetuar atendimentos o se  ³
//³ esta sendo executado pelo EXECAUTO										³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If !IsCaixaLoja( cNumCaixa ) .AND. (nOpc == 3 .OR. nOpc == 4) .AND. !lAutoExec
	Aviso( STR0056, STR0057 + Alltrim(cUserName) + ;  //"Atenção" ### "O usuário "
	STR0058, {STR0028} )  //" não poder  fazer vendas. Utilize a opção Senhas/Caixas no Menu Miscelânea para incluir um Caixa. Caso já exista um cadastrado, re-entre no sistema com uma senha de Caixa." ### "Ok"
	Lj7XSL1('D')
	Return .F.
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Verifica se o usuario e fiscal e se o remote e LINUX ,pois o mesmo nao pode efetuar atendimentos  ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If (GetRemoteType() == REMOTE_LINUX .AND. lFiscal) .AND. !lAutoExec
	Aviso( STR0056, STR0141 , {STR0028} )  //" Atencao## "Não é permitido efetuar o atendimento para o usuário fiscal no ambiente LINUX " ### "Ok"
	Lj7XSL1('D')
	Return (.F.)
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//| Verifica se M0_ESTCOB esta preenchido para a validacao referente a legislacao  |
//| de acordo com cada estado 													   |
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If Empty(SM0->M0_ESTCOB)
   //"Foi detectado que o campo referente ao estado de cobranca(M0_ESTCOB) nao esta configurado."
   //"Solicite ao Administrador para configurar o arquivo sigamat.emp."
	If !lAutoExec
		MsgStop(STR0113 + CRLF + STR0114)
 	Else
 		ConOut(STR0113 + CRLF + STR0114)
 		Help( " ", 1, "Help",, STR0113 + CRLF + STR0114, 1, 0 )
  	EndIf
   Lj7XSL1('D')
   Return .F.
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄP¿
//³Verifica se o ambiente está configurado para integração com o       ³
//³Financial Services. Caso afirmativo, verifica se os parâmetros de   ³
//³cálculo de juros do Financial Services é igual ao parâmetro de      ³
//³cálculo de juros do Protheus para permitir o prosseguimento da venda³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄPÙ
If lUsaIntFS == NIL
	lUsaIntFS	:= SuperGetMV("MV_LJINTFS",,.F.) .And. LjUpd90Ok(, !IsBlind())
EndIf
If lUsaIntFS .AND. cMVLjIFSJu <> cMvJurTipo
	If !lAutoExec
		MsgStop( STR0277  +; //"O módulo controle de lojas está integrado com o Financial Services. "
		          STR0278+;//"Por esta razão, é necessário que parâmetro que indica o tipo de cálculo "
		          STR0279)  //"de juros dos títulos a receber do sistema externo (MV_LJIFSJU) esteja igual ao do ERP (MV_JURTIPO)."
	Else
		ConOut( STR0277  +; //"O módulo controle de lojas está integrado com o Financial Services. "
		          STR0278+;//"Por esta razão, é necessário que parâmetro que indica o tipo de cálculo "
		          STR0279)  //"de juros dos títulos a receber do sistema externo (MV_LJIFSJU) esteja igual ao do ERP (MV_JURTIPO)."
		Help( " ", 1, "Help",, STR0277 + STR0278 + STR0279, 1, 0 )
	EndIf

	Lj7XSL1('D')
	Return .F.
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Se utiliza impressao Concomitante, tem permissao para ³
//³impressao de NF e eh finalizacao da venda, verifica se³
//³o orcamento foi criado como CF ou NF.                 ³
//³DEFAULT: Impressao de Cupom Fiscal                    ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If (  ( LjConcNota() .OR. !lMvLjPDVPa) .OR. !lFiscal ) .AND. nOpc == 4 .AND. !lAutoExec

   	If ExistBlock("LJ7087")
		DbSelectArea("SA1")
		DbSetOrder(1)
		DbSeek(xFilial("SA1") + SL1->L1_CLIENTE + SL1->L1_LOJA)
   		//Chama a funcao LjNFFimVd, pois dentro dela executa o PE "LJ7087"
		LjNFFimVd(.T.				,.F.			,.T.,/*cA1Est*/,;
					/*cA1Pessoa*/	,@nRetLJ7087	)		//Altera para emissao de Nota Fiscal
	EndIf

	//0 = Verifica emissao NF (validacao padrão)  / 1 = Emissão de CF ou NFC-e / 2 = Emissao de nota
	If nRetLJ7087 == 0
	    If LjNfAltDoc(SM0->M0_CGC)
	    	If (lEmitNfce .And. !lUseSat) .Or. lIsPafNfce
	    		cTitDocSai := "N&FC-e"
	    	ElseIf lUseSat
	    		cTitDocSai := IIF(lMFE, "MF-e", "SAT")
	    	Else
	    		cTitDocSai := STR0185 //#"Cupom"#
	    	EndIf
			
			If lFiscal .Or. lEmitNfce .Or. lIsPafNfce
				// Retorno nDocSai -> 1=Emissão de CF ou NFC-e, 2=Emissao de nota ou 3=Cancelou a operação 
				nDocSai := Aviso( STR0183 ,STR0184,{cTitDocSai,STR0186,STR0187}) //"Documento Fiscal de Saida"##"Qual Documento Fiscal de Saida sera impresso na venda?"##"Nota"##"Cancela"

				// Na Finalizacao da venda com IPI avisa em caso de mudanca de regime quando existe SAT na operacao
				If nDocSai <> 3 .AND. !lAutomato .AND. nOpc == 4 .AND. SL1->L1_VALIPI > 0

					// Trocou o regime de saida para SAT mas o orcamento nao era SAT
					If cTitDocSai == 'SAT' .AND. nDocSai == 1 .AND. Empty(SL1->L1_SERSAT)					   
						If !MsgYesNo(STR0442+chr(13)+STR0444+chr(13)+STR0445+chr(13)+STR0446, STR0015)  //'O regime de documento de saída foi alterado para SAT.'##'A alteração pode causar diferença entre o valor orçado e o valor final da venda.'##'A diferença pode ocorrer em vendas com incidência de IPI.'##'Deseja continuar a operação?'
							nDocSai := 3 // Cancelar a operacao
						Endif
					Endif

					// Orcamento SAT mas trocou o regime
					If !Empty(SL1->L1_SERSAT) .AND. (nDocSai == 2 .OR. (nDocSai == 1 .AND. cTitDocSai <> 'SAT'))
						If !MsgYesNo(STR0443+chr(13)+STR0444+chr(13)+STR0445+chr(13)+STR0446, STR0015)  //'O regime de documento de saída foi alterado.'##'A alteração pode causar diferença entre o valor orçado e o valor final da venda.'##'A diferença pode ocorrer em vendas com incidência de IPI.'##'Deseja continuar a operação?'
							nDocSai := 3 // Cancelar a operacao
						Endif
					Endif

				Endif

			Else
				nDocSai := 2 //Se ECF e operacao nao fiscal, finaliza somente como Nota Fiscal
			EndIf

			If nDocSai == 3 // Cancelou a operação, aborta abertura da venda.
				Lj7XSL1('D') // Finaliza o arquivo criado para bloqueio de edicao da venda
				Return .F.
			ElseIf nDocSai == 2
				DbSelectArea("SA1")
				DbSetOrder(1)
				If DbSeek(xFilial("SA1") + SL1->L1_CLIENTE + SL1->L1_LOJA)
					LjNFFimVd(.T.,.F.,.T.,,,,.F.,nDocSai)		//Altera para emissao de Nota Fiscal
				EndIf
			EndIf						
		Else
			If SL1->L1_IMPNF
				nDocSai := 2
				DbSelectArea("SA1")
				DbSetOrder(1)
				If DbSeek(xFilial("SA1") + SL1->L1_CLIENTE + SL1->L1_LOJA)
					LjNFFimVd(.T.,.F.,.T.,,,,.F.,nDocSai)		//Altera para emissao de Nota Fiscal
				EndIf
			EndIf
		EndIf
	EndIf
EndIf

If ExistBlock("LJNoFunc")
	// Ponto de Entrada que tem por objetivo retornar as Funcoes que devem ser desabilitadas da tela do Venda Assistida.
	// Eh passado como parametro o array "aFuncoes" com todas as funcoes padrao.
	// O PE deve retornar um array com os numeros das linhas do array "aFuncoes" cujo as funcoes devem ser sempre desabilitadas. Ex: {4,7,8,9}
	aNoFuncs := ExecBlock( "LJNoFunc", .F., .F., {aFuncoes, nOpc} )
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Ajusta o tamanho do array aBotTB (botoes da toolbar)                    ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
aBotTB := Array( Len(aFuncoes) )

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Define campos do cabecalho 									 ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If LjNfPafEcf(SM0->M0_CGC)
	aCpoEnc	:= { "LQ_NUM","LQ_NUMORC", "LQ_VEND", "LQ_NOMVEND", "LQ_CLIENTE", "LQ_LOJA", "LQ_NOMCLI", "LQ_DTLIM" }

	If !lPreVenda .AND. SuperGetMV("MV_LJDAVOS",,.F.)   // Requisito XLI do Ato Cotepe 0608 para Oficina de Conserto
		aAdd(aCpoEnc , "LQ_NUMFAB"  )
		aAdd(aCpoEnc , "LQ_MARCVEI" )
		aAdd(aCpoEnc , "LQ_MODEVEI" )
		aAdd(aCpoEnc , "LQ_ANOFVEI" )
		aAdd(aCpoEnc , "LQ_PLACVEI" )
		aAdd(aCpoEnc , "LQ_RNVMVEI" )
	EndIf
Else
	aCpoEnc	:= { "LQ_NUM", "LQ_VEND", "LQ_NOMVEND", "LQ_CLIENTE", "LQ_LOJA", "LQ_NOMCLI", "LQ_DTLIM", "LQ_PRODUTO" }
EndIf

If cPaisLoc == "ARG"
	If SLQ->( ColumnPos( "LQ_PROVENT" ) ) > 0
		aAdd( aCpoEnc, "LQ_PROVENT" )
	EndIf
EndIf

If cPaisLoc == "BRA" .AND. lLjMVRecIss
	aAdd( aCpoEnc, "LQ_RECISS" )
EndIf

aAdd( aCpoEnc, "LQ_CODMNEG" )

If cPaisLoc == "BRA" .AND. lMenNota
	aAdd( aCpoEnc, "LQ_MENNOTA" )
EndIf

If cPaisLoc == "ARG" .And. SL1->(FieldPos("L1_ADIC5")) > 0 .And. SLQ->(FieldPos("LQ_ADIC5")) > 0
	aAdd( aCpoEnc, "LQ_ADIC5" )
	aAdd( aCpoEnc, "LQ_ADIC61" )
	aAdd( aCpoEnc, "LQ_ADIC62" )
	aAdd( aCpoEnc, "LQ_ADIC7" )
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Define campos dos itens 									 ³
//³ 															 ³
//³ LR_ITEM		-	01											 ³
//³ LR_PRODUTO	-	02											 ³
//³ LR_DESCRI	-	03											 ³
//³ LR_QUANT	-	04											 ³
//³	LR_VRUNIT	-	05											 ³
//³	LR_VLRITEM	-	06											 ³
//³	LR_UM		-	07											 ³
//³	LR_DESC 	-	08											 ³
//³	LR_VALDESC	-	09											 ³
//³	LR_ENTREGA	-	10	                            			 ³
//³	LR_VDMOST	-	11											 ³
//³	LR_VDOBS	-	12											 ³
//³ 															 ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lPedVen
	aCpoGDa		:= {	"LR_ITEM"	, "LR_PRODUTO", "LR_DESCRI"	, "LR_QUANT", ;
						"LR_VRUNIT"	, "LR_VLRITEM",	"LR_UM"		, "LR_DESC"	, ;
						"LR_VALDESC", "LR_ENTREGA",	"LR_CODCONT", "LR_FDTENTR"}	// Campos da Getdados
Else
	aCpoGDa		:= {	"LR_ITEM"	, "LR_PRODUTO", "LR_DESCRI"	, "LR_QUANT", ;
						"LR_VRUNIT"	, "LR_VLRITEM",	"LR_UM"		, "LR_DESC"	, ;
						"LR_VALDESC", "LR_ENTREGA" }	// Campos da Getdados
EndIf

If lGE
	AAdd(aCpoGDa,"LR_GARANT")			// Campos da Getdados
	AAdd(aCpoGDa,"LR_NSERIE")
	AAdd(aCpoGDa,"LR_ITEMGAR")
EndIf

//Servico Financeiro
If lSFinanc
	If SLR->(FieldPos("LR_ITEMCOB")) > 0
		AAdd(aCpoGDa, "LR_ITEMCOB")
	EndIf

	If SLR->(FieldPos("LR_PRDCOBE")) > 0
		AAdd(aCpoGDa, "LR_PRDCOBE")
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Definicao do arrays que contem os campos da getdados que     ³
//³ poderao ser alterados                                        ³
//³ aCpoGDaDet - Campos da getdados com os detalhes do produto   ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lPedVen
	aAlterGD 	:= { 	"LR_PRODUTO"	, "LR_DESCRI"	, "LR_QUANT"	, "LR_UM"		, ;
						"LR_DESC"		, "LR_VALDESC"	, "LR_ENTREGA"	, "LR_CODCONT"	, ;
						 "LR_FDTENTR"}	// Campos que podem ser alterados na Getdados
Else
	aAlterGD 	:= { 	"LR_PRODUTO", "LR_DESCRI"	, "LR_QUANT"	, "LR_UM"	, ;
   						 "LR_DESC"	, "LR_VALDESC"	, "LR_ENTREGA" }	// Campos que podem ser alterados na Getdados
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Conforme legislacao, em alguns estados nao poderah alterar o valor do Produto. ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
lAlterPre := IIF(IsBlind(),.T., LjCanAtuPr(SM0->M0_CGC) .OR. cPaisLoc <> "BRA" )
If lAlterPre
	aAdd( aAlterGD, "LR_VRUNIT" )
EndIf

If cPaisLoc == "ARG"
	If SLR->( ColumnPos( "LR_PROVENT" ) ) > 0
		aAdd( aCpoGDa, "LR_PROVENT" )
		aAdd( aAlterGD, "LR_PROVENT" )
	EndIf
EndIf

If SLR->(ColumnPos("LR_VDMOST")) > 0
	AADD(aCpoGDa, "LR_VDMOST")
	AADD(aAlterGD, "LR_VDMOST")
EndIf

If SLR->(ColumnPos("LR_VDOBS")) > 0
	AADD(aCpoGDa, "LR_VDOBS")
	AADD(aAlterGD, "LR_VDOBS")
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Se for lAlterOrc esta com a opção de alteracao de orc    ³
//³ entao a função de defpagto nao e chamada                ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lAlterOrc
	aAlterGD 	:= { "LR_ENTREGA" }
EndIf

If ExistFunc("Lj7HasDtEM") .AND. Lj7HasDtEM() .AND. lPedVen
	aAdd( aCpoGda, "LR_FDTMONT" )
	aAdd( aAlterGD, "LR_FDTMONT" )
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Se a comissao for calculada por item, exibe o campo do vendedor no aCols³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If cTpComiss == "2" .OR. cTpComiss == "3"
	AAdd(aCpoGDa,"LR_VEND")
	AAdd(aAlterGD,"LR_VEND")
EndIf

//Comissao de parceiros
If lParceiros
	AAdd(aCpoGDa,"LR_INDPAR")
	AAdd(aAlterGD,"LR_INDPAR")
EndIf

//Verifica se o Processo de Lista esta ativo
If lUsaLstPre
	//Verifica se os campos estao criados e se ja nao estao no array de apresentacao dos campos para incluir
	If SLR->( ColumnPos("LR_CODLPRE") ) > 0 .AND. aScan( aCpoGDa, "LR_CODLPRE" ) == 0
		AAdd(aCpoGDa,"LR_CODLPRE")
	EndIf

	If SLR->( ColumnPos("LR_ITLPRE") ) > 0 .AND. aScan( aCpoGDa, "LR_ITLPRE" ) == 0
		AAdd(aCpoGDa,"LR_ITLPRE")
	EndIf

	If SLR->( ColumnPos("LR_ENTREGA") ) > 0 .AND. aScan( aCpoGDa, "LR_ENTREGA" ) == 0
		AAdd(aCpoGDa,"LR_ENTREGA")
		AAdd(aAlterGD,"LR_ENTREGA")
	EndIf

	If SLR->( ColumnPos("LR_MSMLPRE") ) > 0 .AND. aScan( aCpoGDa, "LR_MSMLPRE" ) == 0	//Codigo da mensagem do Comprador
		AAdd(aCpoGDa,"LR_MSMLPRE")
		AAdd(aCpoGDa,"LR_MSGLPRE")
	EndIf

	If SLR->( ColumnPos("LR_REMLPRE") ) > 0 .AND. aScan( aCpoGDa, "LR_REMLPRE" ) == 0	//Codigo da mensagem do Remetente
		AAdd(aCpoGDa,"LR_REMLPRE")
		AAdd(aCpoGDa,"LR_REVLPRE")
	EndIf
EndIf

If SD2->(ColumnPos("D2_VLIMPOR") ) > 0 .AND. SL2->(ColumnPos("L2_VLIMPOR") ) > 0 ;
   .And. SLR->(ColumnPos("LR_VLIMPOR") ) > 0
	aAdd(aCpoGDa ,"LR_VLIMPOR")
	AAdd(aAlterGD,"LR_VLIMPOR")
EndIf

If SD2->(ColumnPos("D2_FCICOD") ) > 0 .AND. SL2->(ColumnPos("L2_FCICOD") ) > 0 ;
   .And. SLR->(ColumnPos("LR_FCICOD") ) > 0
	aAdd(aCpoGDa ,"LR_FCICOD")
	AAdd(aAlterGD,"LR_FCICOD")
EndIf

If SL2->(ColumnPos("L2_CLASFIS") ) > 0 .And. SLR->(ColumnPos("LR_CLASFIS") ) > 0
	aAdd(aCpoGDa ,"LR_CLASFIS")
	AAdd(aAlterGD,"LR_CLASFIS")
EndIf


If SL2->(ColumnPos("L2_PREDIC") ) > 0 .And. SLR->(ColumnPos("LR_PREDIC") ) > 0
	aAdd(aCpoGDa ,"LR_PREDIC")
	AAdd(aAlterGD,"LR_PREDIC")
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Define campos dos itens da aColsDet (aCols de detalhes dos   ³
//³ produtos                                                     ³
//³                                                              ³
//³ LR_ITEM		-	01											 ³
//³ LR_PRODUTO	-	02											 ³
//³ LR_TES   	-	03											 ³
//³ LR_CF		-	04											 ³
//³	LR_BASEICM	-	05											 ³
//³	LR_VALICM	-	06											 ³
//³	LR_VALIPI	-	07											 ³
//³	LR_VALISS 	-	08											 ³
//³	LR_TABELA	-	09											 ³
//³	LR_DESCPRO	-	10											 ³
//³	LR_PRCTAB	-	11											 ³
//³	LR_FRETE	-	12											 ³
//³	LR_SEGURO	-	13											 ³
//³	LR_DESPESA	-	14											 ³
//³	LR_RESERVA	-	15											 ³
//³	LR_LOJARES	-	16											 ³
//³	LR_ORCRES 	-	17											 ³
//³	LR_EMPRES 	-	18											 ³
//³	LR_FILRES   -	19											 ³
//³	LR_LOCAL    -	20											 ³
//³	LR_NSERIE   -	21											 ³
//³ LR_LOTECTL	-   22  										 ³
//³ LR_NLOTE    -   23											 ³
//³ LR_LOCALIZ  -   24											 ³
//³ LR_DTVALID  -   25	 									 	 ³
//³ LR_CODREG   -   26	 									 	 ³
//³ LR_VLDESRE  -   27	 									 	 ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If cPaisLoc == "BRA"
	aCpoGDaDet	:= {"LR_ITEM"	, "LR_PRODUTO"	, "LR_TES"		, "LR_CF"		, ;
					"LR_BASEICM", "LR_VALICM"	, "LR_VALIPI"	, "LR_VALISS"	, ;
					"LR_TABELA"	, "LR_DESCPRO"	, "LR_PRCTAB"	, "LR_VALFRE"	, ;
					"LR_SEGURO"	, "LR_DESPESA"	, "LR_RESERVA"	, "LR_LOJARES"	, ;
					"LR_ORCRES"	, "LR_EMPRES"	, "LR_FILRES"	, "LR_LOCAL"	, ;
					"LR_NSERIE"	, "LR_LOTECTL"	, "LR_NLOTE"	, "LR_LOCALIZ"	, ;
					"LR_FDTENTR" }  // Campos da Getdados com os detalhes do produto
Else
	aCpoGDaDet	:= {"LR_ITEM"	, "LR_PRODUTO"	, "LR_TES"		, "LR_CF"		, ;
					""			, ""			, ""			, ""			, ;
					"LR_TABELA"	, "LR_DESCPRO"	, "LR_PRCTAB"	, "LR_VALFRE"	, ;
					"LR_SEGURO"	, "LR_DESPESA"	, "LR_RESERVA"	, "LR_LOJARES"	, ;
					"LR_ORCRES"	, "LR_EMPRES"	, "LR_FILRES"	, "LR_LOCAL"	, ;
					"LR_NSERIE"	, "LR_LOTECTL"	, "LR_NLOTE"	, "LR_LOCALIZ" }  // Campos da Getdados com os detalhes do produto
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Adiciona ao array aCpoGda os campos referentes aos impostos...³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	DbSelectArea("SX3")
	DbSetOrder(1)
	DbSeek("SLR")
	While !Eof() .AND. SX3->X3_ARQUIVO == "SLR"
		If (X3Uso(SX3->X3_USADO) .AND. cNivel >= SX3->X3_NIVEL)  .AND.;
		   ("LR_BASIMP"$AllTrim(X3_CAMPO) .OR. "LR_VALIMP"$AllTrim(X3_CAMPO))
			AAdd(aCpoGDaDet,Trim(X3_CAMPO))
		EndIf
		DbSkip()
	End
    If cPaisLoc $ "POR|EUA" .OR. (cPaisLoc$"MEX|COL" )
       AAdd(aCpoGDaDet,"LR_NUMLAY")
       AAdd(aCpoGDaDet,"LR_ITEMLAY")
    EndIf
EndIf

If SLR->(ColumnPos("LR_CLIENT")) > 0
	AADD(aCpoGDa   , "LR_CLIENT")
	AADD(aAlterGD  , "LR_CLIENT")
	aAdd(aCpoGDaDet, "LR_CLIENT" )
EndIf

If SLR->(ColumnPos("LR_CLILOJA")) > 0
	AADD(aCpoGDa   , "LR_CLILOJA")
	aAdd(aCpoGDaDet, "LR_CLILOJA" )
EndIf

If SLR->(ColumnPos("LR_VLTROCA")) > 0
	AADD(aCpoGDa   , "LR_VLTROCA")
	AADD(aAlterGD  , "LR_VLTROCA")
	aAdd(aCpoGDaDet, "LR_VLTROCA" )
EndIf

If SLR->(ColumnPos("LR_ISVFE")) > 0
	aADD(aCpoGDaDet, "LR_ISVFE")
EndIf

If SLR->(ColumnPos("LR_FILPED")) > 0
	AADD(aCpoGDa   , "LR_FILPED")
	aADD(aCpoGDaDet, "LR_FILPED")
EndIf

If SLR->( ColumnPos( "LR_VALEPRE" ) ) > 0
	aAdd( aCpoGDaDet, "LR_VALEPRE" )
EndIf

If SLR->( ColumnPos( "LR_DTVALID" ) ) > 0
	aAdd( aCpoGDaDet, "LR_DTVALID" )
EndIf

If SLR->( ColumnPos( "LR_CODREG" ) ) > 0
	aAdd( aCpoGDaDet, "LR_CODREG" )
EndIf

If SLR->( ColumnPos( "LR_VLDESRE" ) ) > 0
	aAdd( aCpoGDaDet, "LR_VLDESRE" )
EndIf

If lUsaTurno
	aAdd( aCpoGDaDet, "LR_TURNO" )
EndIf

aAdd( aCpoGDaDet, "LR_SITTRIB" )

If lCAT83
	aAdd( aCpoGDaDet, "LR_CODLAN" )
EndIf

If SLR->(FieldPos("LR_CODBAR")) > 0
	aAdd(aCpoGDa   , "LR_CODBAR")
	aAdd(aCpoGDaDet, "LR_CODBAR" )
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Itens do Pedido de Venda DAV(U_UPDFAT14)³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If SLR->(ColumnPos("LR_PEDSC5" ) ) > 0
	aAdd( aCpoGDaDet,"LR_PEDSC5")
	aAdd( aCpoGDaDet,"LR_ITESC6")
	aAdd( aCpoGDaDet,"LR_SEQUEN")
EndIf

If SLR->( FieldPos( "LR_KIT" ) ) > 0
	aAdd( aCpoGDa   , "LR_KIT" )
	aAdd( aCpoGDaDet, "LR_KIT" )
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³SIGAPHOTO - nModulo 72³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If nModulo == 72
	If SLR->( ColumnPos( "LR_ENVELO" ) ) > 0
		aAdd( aCpoGDaDet, "LR_ENVELO" )
	EndIf

	If SLR->( ColumnPos( "LR_BRINDE" ) ) > 0
		aAdd( aCpoGDaDet, "LR_BRINDE" )
	EndIf

	If SLR->( ColumnPos( "LR_CLIENV" ) ) > 0
		aAdd( aCpoGDaDet, "LR_CLIENV" )
	EndIf

	If SLR->( ColumnPos( "LR_LOJENV" ) ) > 0
		aAdd( aCpoGDaDet, "LR_LOJENV" )
	EndIf

	If SLR->( ColumnPos( "LR_PA2ITEM" ) ) > 0
		aAdd( aCpoGDaDet, "LR_PA2ITEM" )
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Verifica se usa reserva sem estoque. Se usar     ³
//³ Grava numero da solicitacao de compra no item    ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If AllTrim(Str(SuperGetMv("MV_LJGERSC",,1))) $ "2|3"
	If SLR->( ColumnPos( "LR_SOLCOM" ) ) > 0
		aAdd( aCpoGDaDet, "LR_SOLCOM" )
	EndIf
EndIf


If lCentPDV
	If SLR->( ColumnPos( "LR_MESREC" ) ) > 0
		aAdd( aCpoGDaDet, "LR_MESREC" )
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Grava Qtde dias da validade da garantia do produto   ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If SLR->( ColumnPos( "LR_VLGAPRO" ) ) > 0
	aAdd( aCpoGDaDet, "LR_VLGAPRO" )
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Tratamento para os campos do e-Commerce              ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If  lECommerce
    If  SLR->(ColumnPos("LR_ECPRESN") > 0)
        If (nOpc != 3)
            aAdd( aCpoGDa, "LR_ECPRESN" )
        EndIf
        aAdd( aCpoGDaDet, "LR_ECPRESN" )
    EndIf
    If  SLR->(ColumnPos("LR_ECSEDEX") > 0)
        If (nOpc != 3)
           aAdd( aCpoGDa, "LR_ECSEDEX" )
        EndIf
        aAdd( aCpoGDaDet, "LR_ECSEDEX" )
    EndIf
    If  SLR->(ColumnPos("LR_ECMSGPR") > 0)
        If (nOpc != 3)
           aAdd( aCpoGDa, "LR_ECMSGPR" )
        EndIf
        aAdd( aCpoGDaDet, "LR_ECMSGPR" )
    EndIf
    If (nOpc != 3)
        aAdd( aCpoGDa, "LR_ECVALOR" )
    EndIf
    aAdd( aCpoGDaDet, "LR_ECVALOR" )
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Release 11.5 - Cartao Fidelidade                                   ³
//³Caso a funcionalidade de recarga de cartao fidelidade estiver ativa³
//³serao acrescentadas as colunas que armazenarao os dados            ³
//³da recarga informados na tela de inclusao de saldo (LOJXFUNH)      ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lLjcFid
	If SLR->( ColumnPos( "LR_NUMCFID" ) ) > 0
		aAdd( aCpoGDaDet, "LR_NUMCFID" )
	EndIf

	If SLR->( ColumnPos( "LR_DTSDFID" ) ) > 0
		aAdd( aCpoGDaDet, "LR_DTSDFID" )
	EndIf

	If SLR->( ColumnPos( "LR_VLRCFID" ) ) > 0
		aAdd( aCpoGDaDet, "LR_VLRCFID" )
	EndIf
EndIf

//PAF-ECF: Campo para controle do item do PAF, quando possui MD5 sinaliza que esta armazenado no BD
If SLR->( ColumnPos( "LR_PAFMD5" ) ) > 0
	aAdd( aCpoGDaDet, "LR_PAFMD5" )
EndIf

If SLR->(ColumnPos("LR_CODISS")) > 0
	aAdd( aCpoGDaDet, "LR_CODISS" )
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Grava Qtde dias da validade da garantia do produto   ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lGE
	aAdd( aCpoGDaDet, "LR_VLGAPRO" )
EndIf

//NFC-E
If lEmitNfce .Or. lIsPafNfce

	If SLR->(ColumnPos( "LR_ORIGEM" )) > 0
		aAdd( aCpoGDaDet, "LR_ORIGEM" )
	EndIf

	If SLR->(ColumnPos( "LR_MODBC" )) > 0
		aAdd( aCpoGDaDet, "LR_MODBC" )
	EndIf

	If SLR->(ColumnPos( "LR_POSIPI" )) > 0
		aAdd( aCpoGDaDet, "LR_POSIPI" )
	EndIf

ElseIf lIntegDef
    If SLR->(ColumnPos( "LR_POSIPI" )) > 0
        aAdd( aCpoGDaDet, "LR_POSIPI" )
    EndIf
EndIf

If SLR->( ColumnPos( "LR_DESCICM" ) ) > 0
	aAdd( aCpoGDaDet, "LR_DESCICM" )
EndIf

If SLR->( ColumnPos( "LR_MOTDICM" ) ) > 0
	aAdd( aCpoGDaDet, "LR_MOTDICM" )
EndIf

//Integracao Mensagem Unica adiciona impostos Pis e Cofins
If lIntegDef
	aAdd(aCpoGDaDet, "LR_PICM")
	aAdd(aCpoGDaDet, "LR_ALIQISS")
	aAdd(aCpoGDaDet, "LR_BASEISS")
	aAdd(aCpoGDaDet, "LR_VALPS2")
	aAdd(aCpoGDaDet, "LR_BASEPS2")
	aAdd(aCpoGDaDet, "LR_ALIQPS2")	
	aAdd(aCpoGDaDet, "LR_VALCF2")
	aAdd(aCpoGDaDet, "LR_BASECF2")
	aAdd(aCpoGDaDet, "LR_ALIQCF2")		
	aAdd(aCpoGDaDet, "LR_VALCOFI")
	aAdd(aCpoGDaDet, "LR_BASECOF")
	aAdd(aCpoGDaDet, "LR_ALIQCOF")		
	aAdd(aCpoGDaDet, "LR_VALPIS")
	aAdd(aCpoGDaDet, "LR_BASEPIS")
	aAdd(aCpoGDaDet, "LR_ALIQPIS")		
	aAdd(aCpoGDaDet, "LR_BASCSLL")
	aAdd(aCpoGDaDet, "LR_ALQCSLL")
	aAdd(aCpoGDaDet, "LR_VALCSLL")
	aAdd(aCpoGDaDet, "LR_TOTFED")
	aAdd(aCpoGDaDet, "LR_TOTEST")
	aAdd(aCpoGDaDet, "LR_TOTMUN")
	aAdd(aCpoGDaDet, "LR_BASIRRF")
	aAdd(aCpoGDaDet, "LR_VALIRRF")
	aAdd(aCpoGDaDet, "LR_ALQIRRF")
	If SLR->(ColumnPos("LR_BASFECP")) > 0
		aAdd(aCpoGDaDet, "LR_BASFECP")
	EndIf
	If SLR->(ColumnPos("LR_VALFECP")) > 0
		aAdd(aCpoGDaDet, "LR_VALFECP")
	EndIf
	If SLR->(ColumnPos("LR_ALQFECP")) > 0
		aAdd(aCpoGDaDet, "LR_ALQFECP")
	EndIf
	If SLR->(ColumnPos("LR_BSFCPST")) > 0
		aAdd(aCpoGDaDet, "LR_BSFCPST")
	EndIf
	If SLR->(ColumnPos("LR_VFECPST")) > 0
		aAdd(aCpoGDaDet, "LR_VFECPST")
	EndIf
	If SLR->(ColumnPos("LR_ALQFCST")) > 0
		aAdd(aCpoGDaDet, "LR_ALQFCST")
	EndIf
	If SLR->(ColumnPos("LR_IPI")) > 0 .And. SL2->(ColumnPos("L2_IPI")) > 0
		aAdd(aCpoGDaDet, "LR_IPI")
	EndIf
	If SLR->(ColumnPos("LR_BASEIPI")) > 0 .And. SL2->(ColumnPos("L2_BASEIPI")) > 0
		aAdd(aCpoGDaDet, "LR_BASEIPI")
	EndIf
	aAdd(aCpoGDaDet, "LR_BRICMS")
	aAdd(aCpoGDaDet, "LR_ICMSRET")
	If SLR->(ColumnPos("LR_ALIQSOL")) > 0 .And. SL2->(ColumnPos("L2_ALIQSOL")) > 0
		aAdd(aCpoGDaDet, "LR_ALIQSOL")
	EndIf
	
	If lIntegHtl //Integracao Hotelaria
		aAdd(aCpoGDaDet, "LR_CLVL")
		aAdd(aCpoGDaDet, "LR_ITEMCC")
		aAdd(aCpoGDaDet, "LR_CCUSTO")
	EndIf				
EndIf

If SLR->(ColumnPos("LR_CEST")) > 0
	aAdd( aCpoGDaDet, "LR_CEST" )
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Reinicia controles das regras de desconto para a venda assistida³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
LjDescRst()

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Verifica se é inclusão ou alteracao para fazer o tratamento  ³
//³ para os campos da enchoice. ( Le os campos do SL1 e armazena ³
//³ nas variaveis de memoria do SLQ )                            ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If nOpc == 3

	RegToMemory( "SLQ", .T. )
	RegToMemory( "SLR", .T. )

	//³ Caso o SXE e o SXF estejam corrompidos cNumOrc estava se repetindo.³
    lTemGeraNOrc := LjTemGeraNOrc()
    
	If lLjNfPafEcf
		lValida := IIF(!lTemGeraNOrc, .T., .F.)
	Else
		lValida := IIF(!LjAnalisaLeg(37)[1] .OR. !lTemGeraNOrc, .T., .F.)
	EndIf

	If lValida
		cMay := Alltrim(xFilial("SL1"))+M->LQ_NUM
		FreeUsedCode()
		SL1->(DbSetOrder(1))
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Se dois orcamentos iniciam ao mesmo tempo a MayIUseCode impede que ambos utilizem o mesmo numero.³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		nTent := 0
		While SL1->(MsSeek(xFilial("SL1")+M->LQ_NUM)) .OR. !MayIUseCode(cMay)
			If ++nTent > 20
				If !lAutoExec
					Final(STR0059)  //"Impossivel gerar numero sequencial de orcamento correto. Informe ao administrador do sistema."
				Else
					ConOut(STR0059)
					Help( " ", 1, "Help",, STR0059, 1, 0 )
					Return
				Endif
			EndIf
			While (GetSX8Len() > nSaveSx8)
				ConfirmSx8()
			End
			M->LQ_NUM    := CriaVar("LQ_NUM")
			FreeUsedCode()
			cMay := Alltrim(xFilial("SL1"))+M->LQ_NUM
		End
	EndIf
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Preenche os dados da Enchoice com informacoes padrão mas      ³
	//³prioriza a  dados da Enchoice com informacoes padrão          ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If !lAutoExec
		M->LQ_VEND    := PadR(If(Empty(M->LQ_VEND),cVendPad,M->LQ_VEND),nTamLQ_VEND," ")
		M->LQ_NOMVEND := PadR(If(Empty(M->LQ_NOMVEND),Posicione( "SA3",1,xFilial("SA3")+cVendPad,"SA3->A3_NOME" ),M->LQ_NOMVEND),nTamLQ_NOMVEND," ")
		M->LQ_CLIENTE := PadR(If(Empty(M->LQ_CLIENTE),cCliPad,M->LQ_CLIENTE),nTamLQ_CLIENTE," ")
		M->LQ_LOJA    := PadR(If(Empty(M->LQ_LOJA),cLojPad,M->LQ_LOJA),nTamLQ_LOJA," ")
		M->LQ_NOMCLI  := PadR(If(Empty(M->LQ_NOMCLI),Posicione( "SA1",1,xFilial("SA1")+cCliPad+cLojPad,"SA1->A1_NOME" ),M->LQ_NOMCLI),nTamLQ_NOMCLI," ")

		If cPaisLoc == "ARG" .And. SL1->(ColumnPos("L1_ADIC5")) > 0 .And. SLQ->(ColumnPos("LQ_ADIC5")) > 0
			M->LQ_ADIC5   := PadR(If(Empty(M->LQ_ADIC5),Posicione( "SA1",1,xFilial("SA1")+cCliPad+cLojPad,"SA1->A1_ADIC5" ),M->LQ_ADIC5),nTamADIC5," ")
			M->LQ_ADIC61  := PadR(If(Empty(M->LQ_ADIC61),Posicione( "SA1",1,xFilial("SA1")+cCliPad+cLojPad,"SA1->A1_ADIC61" ),M->LQ_ADIC61),nTamADIC61," ")
			M->LQ_ADIC62  := PadR(If(Empty(M->LQ_ADIC62),Posicione( "SA1",1,xFilial("SA1")+cCliPad+cLojPad,"SA1->A1_ADIC62" ),M->LQ_ADIC62),nTamADIC62," ")
			M->LQ_ADIC7   := PadR(If(Empty(M->LQ_ADIC7),Posicione( "SA1",1,xFilial("SA1")+cCliPad+cLojPad,"SA1->A1_ADIC7" ),M->LQ_ADIC7),nTamADIC7," ")
		Endif
	Endif
	cOldTpFrete := M->LQ_TPFRET
Else
	RegToMemory( "SLQ", .F., .F. )
	RegToMemory( "SLR", .F., .F. )

	DbSelectArea("SX3")
	DbSetOrder(1)
	MsSeek("SLQ")
	While !Eof() .AND. SX3->X3_ARQUIVO == "SLQ"
		If X3Uso(SX3->X3_USADO) .AND. cNivel >= SX3->X3_NIVEL
			cVar := "M->" + Alltrim(SX3->X3_CAMPO)
			If SX3->X3_CONTEXT == "V"
				bBloco := { || &(cVar) := Criavar(SX3->X3_CAMPO) }
			Else
				bBloco := &("{ || &(cVar) := SL1->(FieldGet(ColumnPos('L1_"+Alltrim(Substr(SX3->X3_CAMPO,4,Len(SX3->X3_CAMPO)))+"'))) }")
			EndIf
			Eval( bBloco )
		EndIf
		SX3->(DbSkip())
	End
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Alimento as variaveis de impostos para o caso de finalizacao da venda³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If SL1->( ColumnPos("L1_VALPIS")) > 0 .AND. ;
       SL1->( ColumnPos("L1_VALCOFI")) > 0 .AND. ;
       SL1->( ColumnPos("L1_VALCSLL")) > 0

		LJPCCIni(SL1->L1_CLIENTE, SL1->L1_LOJA, SL1->L1_EMISSAO)

		If SL1->L1_VALPIS > nRetPis
			LJPCCAlt("SL", { SL1->L1_VLRTOT, SL1->L1_VALPIS })
		EndIf

		If SL1->L1_VALCOFI > nRetCof
			LJPCCAlt("SL", { ,, SL1->L1_VALCOFI })
		EndIf

		If SL1->L1_VALCSLL > nRetCsl
			LJPCCAlt("SL", { ,,, SL1->L1_VALCSLL })
		EndIf
	EndIf
EndIf

//Zera a variável do IPI e-commerce
If ExistFunc("Lj7SetIPEC")
	Lj7SetIPEC(0)
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Define campos da Getdados. Se for alteracao eh responsavel   ³
//³ por carrecar os dados do orcamento e dados de pagamento.     ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Lj7MontaGD(  "SLR"      , @aCpoGDa	, nOpc			,aCpoGDaDet	,;
             @aAlterGD	, cFilContra, @nVlrAcrsFi	)

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Release 11.5 - Controle de Formularios                        ³
//³Apresentar a tela "Dados do Formulario" para que o usuario 	 ³
//³informe os dados do formulario que sera utilizado na venda 	 ³
//³Paises: Chile/Colombia - F1CHI								 ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If (nOpc==3 .OR. nOpc==4).AND. lCFolLocR5
	If Iif(!lAutoExec,!LjxEspxFo(@cSigEspFo,@cDocFo,NIL,@nRecnoFo),.T.)
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Se realizou uma troca, verifica se deseja estornar a operacao³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If Len(aCopyDev) > 0 .AND. nOpc <> 2 .AND. aCopyDev[5] == 1
		   If lAutoExec .OR. (!lAutoExec .AND. MsgYesNo(STR0230))		// "Confirma o cancelamento da operação de troca/devolução ?"
		      Lj720EstTroc(aCopyDev)
		      Return (.F.)
		   EndIf
		EndIf

		If !(Len(aCopyDev) > 0) .AND. !(nOpc <> 2) .AND. !(aCopyDev[5] == 1 )
			Return Nil
		EndIf
	EndIf
EndIf

If nOpc == 3

	If MaFisFound("NF")
		MaFisEnd()
	EndIf

	aVetTemp := LjRecLog(M->LQ_NUM)

	M->LQ_NOMVEND := PadR(Posicione( "SA3",1,xFilial("SA3")+M->LQ_VEND,"SA3->A3_NOME" ),nTamLQ_NOMVEND," ")
	M->LQ_NOMCLI  := PadR(Posicione( "SA1",1,xFilial("SA1")+M->LQ_CLIENTE+M->LQ_LOJA,"SA1->A1_NOME" ),nTamLQ_NOMCLI," ")

	If cPaisLoc == "ARG" .And. SL1->(FieldPos("L1_ADIC5")) > 0 .And. SLQ->(FieldPos("LQ_ADIC5")) > 0
		M->LQ_ADIC5   := PadR(Posicione( "SA1",1,xFilial("SA1")+M->LQ_CLIENTE+M->LQ_LOJA,"SA1->A1_ADIC5" ),nTamADIC5," ")
		M->LQ_ADIC61  := PadR(Posicione( "SA1",1,xFilial("SA1")+M->LQ_CLIENTE+M->LQ_LOJA,"SA1->A1_ADIC61" ),nTamADIC61," ")
		M->LQ_ADIC62  := PadR(Posicione( "SA1",1,xFilial("SA1")+M->LQ_CLIENTE+M->LQ_LOJA,"SA1->A1_ADIC62" ),nTamADIC62," ")
		M->LQ_ADIC7   := PadR(Posicione( "SA1",1,xFilial("SA1")+M->LQ_CLIENTE+M->LQ_LOJA,"SA1->A1_ADIC7" ),nTamADIC7," ")
	EndIf

	If Len(aVetTemp) == 2

		aCols    := aClone(aVetTemp[01])
		aColsDet := aClone(aVetTemp[02])
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Inicializa a parte fiscal dos produtos.³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		nPosProd    := aScan(aHeader, { |x| AllTrim(x[02]) == "LR_PRODUTO" })
		nPosTES     := aScan(aHeaderDet, { |x| AllTrim(x[02]) == "LR_TES" })
		nPosQuant   := aScan(aHeader, { |x| AllTrim(x[02]) == "LR_QUANT" })
		nPosPRCTab  := aScan(aHeaderDet, { |x| AllTrim(x[02]) == "LR_PRCTAB" })
		nPosValDesc := aScan(aHeader, { |x| AllTrim(x[02]) == "LR_VALDESC" })
		lCalcIPI    := Ascan(aPosCpoDet,{|x| Alltrim(Upper(x[1])) == "LR_VALIPI"})	 > 0
		cTpFrete := Lj7TpFrete(M->LQ_CLIENTE,M->LQ_LOJA)
		cTpFrete	:= IIf( Empty(cTpFrete) .And. (M->LQ_TPFRET == "S" .OR. M->LQ_TPFRET == "0"), "S", cTpFrete)

		MaFisIni( M->LQ_CLIENTE , M->LQ_LOJA , "C"  , "S"  ,;
		          NIL           , NIL         , NIL  , .F. ,;
		          "SB1"         , cNomeProg   , NIL  , NIL ,;
		          NIL           , NIL         , NIL  , NIL ,;
		          NIL           , NIL         , NIL  , lCalcIPI ,;
		          NIL           , NIL        	, NIL 	, NIL	,;
		          NIL           , cTpFrete )
		          
		IF ExistFunc("LjSatMxFis")
			LjSatMxFis()
		EndIf

		For nX := 1 To Len(aCols)
		    //ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Adiciona as variaveis nas funcoes fiscais                    ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			MaFisAdd( aCols[nX,nPosProd]     ,;                // Produto
			          aColsDet[nX,nPosTES]   ,;                // TES
			          aCols[nX,nPosQuant]    ,;                // Quantidade
			          aColsDet[nX,nPosPRCTab],;                // Preco unitario
			          aCols[nX,nPosValDesc]  ,;                // Valor do desconto
			          ""                     ,;                // Numero da NF original
			          ""                     ,;                // Serie da NF original
			          0                      ,;                // Recno da NF original
			          0                      ,;                // Valor do frete do item
			          0                      ,;                // Valor da despesa do item
			          0                      ,;                // Valor do seguro do item
			          0                      ,;                // Valor do frete autonomo
			          ( aColsDet[nX,nPosPRCTab] * aCols[nX,nPosQuant] ),;  // Valor da mercadoria
			          0 )                                      // Valor da embalagem

			If ! aCols[nX,Len(aCols[nX])]
				Lj7T_SubTotal( 2, ( Lj7T_SubTotal(2) + MaFisRet(nX, "IT_TOTAL") ))
			EndIf
		Next nX
		Lj7T_Total( 2, Lj7T_SubTotal(2))
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Define posicao dos objetos									 ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Lj7RetPos( aSize1    , @aPosObj1 , @aPosObj2 , @aPosObj3 , ;
           @aPosObj4 , @aPosObj5 )

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Identifica o cliente caso utiliza TEF e cartoes CCS          ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lUsaTef .AND. lIntegLoja .AND. lTefMilha
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³aRet[1] ->Retorna o tipo do cartao³
	//³1 - Magnetico                     ³
	//³2 - Não Magnético                 ³
	//³3- CPF                            ³
	//³4- Abandona                       ³
	//³aRet[2] -> O dado sendo:          ³
	//³1,2 -> Numero do cartão           ³
	//³3 -> numero do cpf                ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ "C" - Pesquisa o CPF no CCS e retorna o numero do cartao³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	aCartaoMH:=L010TCart('C')
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Carrega fontes												 ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
LjFontes()

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Alimenta as variaveis de numero de contrato na finalizacao da venda³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If CrdxInt() .AND. nOpc == 4
   Lj7SetContra()
EndIf

/*Verifica se existe cupom aberto e tenta cancelar se não conseguir
o caixa não poderá trabalhar com a impressora para o caso da     
venda ser concomitante                                           
Nao faz o cancelamento do cupom quando for finalizacao da venda. */
If !lIsPafNfce .And. lVAssConc .AND. nOpc == 3 .AND. !lAutoExec
	Lj7Canc(.F.) //.T. - Pergunta antes .F. - Não pergunta se deseja cancelar

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Se foram recuperados itens de um orcamento anterior, ³
	//³estes devem ser registrados novamente no ECF.        ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If Len(aVetTemp) == 2
		For nX := 1 to Len(aCols)
			N := nX
			LJ7ImpItCC( N )
		Next nX
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Verifica se utiliza troca de serie automatica quando o COO for reinicializado.³
//³Emite aviso para rodar a rotina de reserva de series.                         ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If nOpc ==3 .OR. nOpc ==4
	LJNSrDisp()
	Lj720SetTroca(.F.)                // Seta(inicializa) a variavel estatica lTroca = .F.
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Verifica se a data do orcamento esta diferente da data atual e analisa se  ³
//³ esta deve ser atualizada, de acordo com o parametro MV_LJDTORC, onde:      ³
//³ "N" - Nunca Ajusta as datas, ou seja, sempre a que foi gravada             ³
//³ "S" - Sempre Ajusta as datas, ou seja, Atualiza a data baseado no dia atual³
//³ "P" - Pergunta, ou seja, fara uma pergunta se deseja ajustar as datas      ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If nOpc == 3 .AND. lAutoExec .AND. (lECommerce .OR. lEmitNFCe .Or. lIsPafNfce)
	lLJDTOrc := .F.
EndIf

If nOpc == 4 .AND. dDataBase > M->LQ_EMISSAO .AND. !lAutoExec

	lLJDTOrc := (cLJDTORC == "S")

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Pergunta ao usuario quando o parametro for igual a 'P'³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If cLJDTORC == "P"
		lLJDTORC := MsgYesNo( STR0111 ) //"Deseja ajustar as datas das parcelas do orcamento, com base na data de hoje?"
	EndIf

	If lLJDTOrc

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Ajusta data das parcelas ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		For nX := 1 to Len(aPgtos)
			aPgtos[nX][1] := DataValida( aPgtos[nX][1] + (dDatabase - M->LQ_EMISSAO) )
		Next nX

		M->LQ_EMISSAO := dDataBase

	Else
	
		If Empty(M->LQ_EMISSAO)
			M->LQ_EMISSAO := SL1->L1_EMISSAO
		Endif

	EndIf

EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Para a finalizacao da venda, a aTotImps esta zerada³
//³sendo que o correto eh estar preenchida            ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If nOpc == 4 .AND. cPaisLoc <> "BRA"
	If Len(aTotImpsV) == 0
		For nX := 1 To Len(aColsDet)
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Verifica se esta deletado³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If !aColsDet[nX][Len(aColsDet[nX])]
				Lj7TotImpsV(nX, 7)
			EndIf
		Next nX
	EndIf
EndIf

If nModulo == 5
	cCadastro	:= STR0148 //"Venda Direta"
Else
	cCadastro	:= STR0122 //"Venda Assistida"
EndIf

If !lAutoExec
	DEFINE MSDIALOG oDlgVA TITLE cCadastro + ' - ' + aRotina[nOpc][1] FROM aSize1[7],0 TO aSize1[6],aSize1[5] OF oMainWnd PIXEL  //"Venda Assistida"

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Cria Enchoice.³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If !lFtvdVer12
		oEncVA   := MsMGet():New("SLQ", nReg, If(!lAltDados,2,nOpc), , , , aCpoEnc, aPosObj3[1], , 3, , , , , , .T.)
	ElseIf lFtvdVer12
		oEncVA   := MsMGet():New("SLQ", nReg, If(!lAltDados,2,nOpc), , , , aCpoEnc, aPosObj3[2], , 3, , , , , , .T.)
	EndIf
	
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Criacao do bmp que contera a toolbar do lado direito		 ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	@ aPosObj1[ 2,1 ] - 15, aPosObj1[ 2,2 ] BITMAP oBarBmp RESNAME "PROJETOAP" OF oDlgVA SIZE aPosObj1[ 2,3 ] ,aPosObj1[ 2,4 ] NOBORDER PIXEL

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Cria botoes da toolbar a direita							 ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	nCount2 := Len(aFuncoes)
	nCount3	:= 0
	For nCount1 := 1 To nCount2
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Funcao aparece na toolbar ?									 ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If aFuncoes[nCount1, 5]
			nCount3 ++
			@ aPosObj2[ nCount3,1 ], aPosObj2[ nCount1,2 ]*2 BTNBMP aBotTB[nCount3] RESOURCE Lj7F_Imag(nCount1) SIZE aPosObj2[ 1,3 ], aPosObj2[ 1,4 ] OF oDlgVA PIXEL MESSAGE Lj7F_Dica(nCount1)
			aBotTB[nCount3]:bAction := Lj7F_Func(nCount1)
		EndIf
		Lj7F_Menu( nCount1, Lj7F_Menu( nCount1 ))  // Habilita ou desabilita o menu e setkey.
	Next nCount1

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Cria variavel para controle de alteracao na enchoice e       ³
	//³ getdados. Quando for um orcamento criado pela rotina de      ³
	//³ reserva nao poderah permitir alteracoes nos dados.           ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If !lAlterOrc
		lAltDados := If( nOpc == 4 .AND. !Empty(SL1->L1_ORCRES) .AND. !Empty(SL1->L1_FILRES), .F., .T. )
	Else
		lAltDados := .T.
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Verifica se orçamento ja foi importado para o pdv.          ³
	//³ Caso sim, nao podera alterar o orçamento no retaguarda,     ³
	//³ apenas visualizar.       					                ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If lAltDados .AND. nOpc==4
		lAltDados := FR271CVldImp(SL1->L1_NUM) 	// Se .T. nao foi importado ainda
		If !lAltDados
			MsgStop(STR0159+ SL1->L1_NUM + STR0431, STR0001 )// O Orçamento "###" já foi finalizado em outro Ponto de Venda. Será aberto apenas para visualização."					
            nOpc:=2 // Apenas Visualizar            	   		
	   	EndIf
	   	
	   	If lAltDados .And. !FR271CVldImp(SL1->L1_NUM, .T.)
	       MsgStop(STR0159+ SL1->L1_NUM + STR0162, STR0001 )// O Orçamento "###" já foi importado da Retaguarda por outro Ponto de Venda." 
	   	EndIf
	EndIf
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Cria a Getdados e Panel								         ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If !lFtvdVer12

		oGetVA   := MsGetDados()	:New(aPosObj3[2,1], aPosObj3[2,2], aPosObj3[2,3], aPosObj3[2,4], If(!lAltDados,2,nOpc),"Lj7LinOk",,"+LR_ITEM",.T., aAlterGD,,.T., 1000,"Lj7VlField",,,If(!lAltDados .OR. nOpc == 2,"(.F.)","Lj7PrepDel"), oDlgVA)

		oGetVA:oBrowse:bGotFocus	:= {|| Lj7CabOk(oEncVA) }

		If LjDatFon()
			oGetVA:bEditCancel	:= {||	LjGetCancel(oGetVA) }
		EndIf

		oTitulo  := TCBrowse()		:New(aPosObj3[1,2]+12, aPosObj3[1,1]-40, aPosObj3[1,4]-6, aPosObj3[1,3]-6,,,{20,30,22,33,35,35,35,35,35},oDlgVA,,,,,,,,,,,,,,.T.)
		oTitulo:lVisible := .F.

		oPanVA1  := TPanel()		:New(aPosObj3[3,1], aPosObj3[3,2], "", oDlgVA, NIL, .T., .F.,;
								 NIL, NIL, aPosObj3[3,3], aPosObj3[3,4], .T., .F. )

		oPanVA2  := TPanel()		:New(aPosObj3[4,1], aPosObj3[4,2], "", oDlgVA, NIL, .T., .F.,;
								 NIL, NIL, aPosObj3[4,3], aPosObj3[4,4], .T., .F. )
	ElseIf lFtvdVer12

		oGetVA   := MsGetDados()	:New(aPosObj3[3,1], aPosObj3[3,2], aPosObj3[3,3], aPosObj3[3,4], If(!lAltDados,2,nOpc),"Lj7LinOk",,"+LR_ITEM",.T., aAlterGD,,.T., 1000,,,,If(!lAltDados .OR. nOpc == 2,"(.F.)","Lj7PrepDel"), oDlgVA)

		oGetVA:oBrowse:bGotFocus	:= {|| Lj7CabOk(oEncVA) }

		oTitulo  := TCBrowse()		:New(aPosObj3[2,2]+12, aPosObj3[2,1]-40, aPosObj3[2,4]-6, aPosObj3[2,3]-6,,,{20,30,22,33,35,35,35,35,35},oDlgVA,,,,,,,,,,,,,,.T.)
		oTitulo:lVisible := .F.

		oPanVA1  := TPanel()		:New(aPosObj3[4,1], aPosObj3[4,2], "", oDlgVA, NIL, .T., .F.,;
									 NIL, NIL, aPosObj3[4,3], aPosObj3[4,4], .T., .F. )

		oPanVA2  := TPanel()		:New(aPosObj3[5,1], aPosObj3[5,2], "", oDlgVA, NIL, .T., .F.,;
									 NIL, NIL, aPosObj3[5,3], aPosObj3[5,4], .T., .F. )
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Cria botoes do menu 										 ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	@ 01, 010	BUTTON STR0085  	SIZE 50, 12 OF oDlgVA PIXEL ACTION Lj7MPopUp( 1, @oPanVA3, aPosObj4 )  //"Gravação"
	@ 01, 065	BUTTON STR0086  	SIZE 50, 12 OF oDlgVA PIXEL ACTION Lj7MPopUp( 2, @oPanVA3, aPosObj4 )	//"Detalhes"
	@ 01, 120	BUTTON STR0087  	SIZE 50, 12 OF oDlgVA PIXEL ACTION Lj7MPopUp( 3, @oPanVA3, aPosObj4 )	//"Estoque"
	@ 01, 175	BUTTON STR0088  	SIZE 50, 12 OF oDlgVA PIXEL ACTION Lj7MPopUp( 4, @oPanVA3, aPosObj4 )	//"Outros"

	If ExistBlock("FT701BTN") .AND. lFtvdVer12
		aRet := ExecBlock("FT701BTN",.F.,.F.)
		If ValType( aRet ) == "A"
			@ 01, 230	BUTTON aRet[1]  	SIZE 50, 12 OF oDlgVA PIXEL ACTION EVAL(aRet[2])
		EndIf
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Cria os objetos para Sub-total								 ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	@ 05, aPosObj5[1,2]	SAY aTotais[1, 5]	VAR aTotais[1, 1]								SIZE 070,08 OF oPanVA1	PIXEL 						FONT aFontes[1]
	@ 05, aPosObj5[2,2]	SAY aTotais[1, 3]	VAR Transform( aTotais[1, 2], aTotais[1, 4] )	SIZE 044,10 OF oPanVA1	PIXEL RIGHT COLOR CLR_HRED	FONT aFontes[1]

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Cria os objetos para Desconto %								 ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	@ 05, aPosObj5[3,2]	SAY aTotais[2, 5]	VAR aTotais[2, 1]								SIZE 040,08 OF oPanVA1	PIXEL 						FONT aFontes[1]
	@ 05, aPosObj5[4,2]	SAY aTotais[2, 3] 	VAR Transform( aTotais[2, 2], aTotais[2, 4] )	SIZE 028,10 OF oPanVA1	PIXEL RIGHT COLOR CLR_HRED	FONT aFontes[1]

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Cria os objetos para Desconto $								 ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	@ 05, aPosObj5[5,2]	SAY aTotais[3, 5]	VAR aTotais[3, 1]								SIZE 040,08 OF oPanVA1	PIXEL 						FONT aFontes[1]
	@ 05, aPosObj5[6,2]	SAY aTotais[3, 3]	VAR Transform( aTotais[3, 2], aTotais[3, 4] )	SIZE 030,10 OF oPanVA1	PIXEL RIGHT COLOR CLR_HRED	FONT aFontes[1]

	If !lFtvdVer12

		//Total Volume
		@ 04, aPosObj5[7,2]	SAY aTotais[7, 5]	VAR aTotais[7, 1]								SIZE 050,08 OF oPanVA1	PIXEL 						FONT aFontes[2]
		@ 04, aPosObj5[8,2]	SAY aTotais[7, 3]	VAR Transform( aTotais[7, 2], aTotais[7, 4] )	SIZE 030,10 OF oPanVA1	PIXEL RIGHT COLOR CLR_HRED	FONT aFontes[2]

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Cria os objetos para Total 										 ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		@ 04, aPosObj5[9,2]		SAY aTotais[4, 5]	VAR aTotais[4, 1]								SIZE 070,08 OF oPanVA1	PIXEL 						FONT aFontes[2]
		@ 04, aPosObj5[10,2]	SAY aTotais[4, 3]	VAR Transform( aTotais[4, 2], aTotais[4, 4] )	SIZE 065,10 OF oPanVA1	PIXEL RIGHT COLOR CLR_HRED	FONT aFontes[2]

	ElseIf lFtvdVer12

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Cria os objetos para Total 										 ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		@ 04, aPosObj5[7,2]	SAY aTotais[4, 5]	VAR aTotais[4, 1]								SIZE 090,08 OF oPanVA1	PIXEL 						FONT aFontes[2]
		@ 04, aPosObj5[8,2]	SAY aTotais[4, 3]	VAR Transform( aTotais[4, 2], aTotais[4, 4] )	SIZE 065,10 OF oPanVA1	PIXEL RIGHT COLOR CLR_HRED	FONT aFontes[2]

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Cria os objetos para Desconto Suframa 										 ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		@ 04, aPosObj5[10,2] SAY aTotais[7, 5]	VAR aTotais[7, 1]								SIZE 120,08 OF oPanVA1	PIXEL 						FONT aFontes[2]
		@ 04, aPosObj5[11,2] SAY aTotais[7, 3]	VAR Transform( aTotais[7, 2], aTotais[7, 4] )	SIZE 028,10 OF oPanVA1	PIXEL RIGHT COLOR CLR_HRED	FONT aFontes[2]


	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Cria os objetos para O Rodape						         ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	@ 01, 01	        SAY aRodape[1, 2]	VAR aRodape[1, 1]								SIZE 490,08 OF oPanVA2	PIXEL 						FONT aFontes[1]

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Cria interface para definicao dos pagamentos				 ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Se for lAlterOrc esta com a opção de alteracao de orc    ³
	//³ entao a função de defpagto nao e chamada                ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If !lAlterOrc
		LJ7DefPag(.T., @oPanVA3, aPosObj4, oEncVA, nOpc, @lTefPendCS, @aTefBKPCS, @cAlterCond, NIL, @nVlrAcrsFi, Nil, Nil, @aDadosCNeg)
		If lVisuSint
			aPgtosSint := Lj7MontPgt(aPgtos)
			oPgtosSint:SetArray( aPgtosSint )
			oPgtosSint:Refresh()
		EndIf
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Tratamento para não causar diferença de centavos quando for utilizado  ³
	//³ o P.E. FRTECF13 e o orçamento for feito em uma estação não fiscal e    ³
	//³ finalizado em uma estação com ECF.                                     ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ      
    If lFRTECF13 .AND. nOpc == 4 
    
        cBkReadVar := ReadVar()
        nBkp       := N      
        
        For nI := 1 To Len(aCols)
            If !aCols[nI][Len(aCols[nI])]
                N := nI                 
                lj7VlItem(3,,,,.T.,,,,,,,,, !Empty(M->LQ_CONDPG))                
            EndIf   
        Next
        
        N := nBkp   
        __ReadVar := cBkReadVar        
    Endif
    
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Se o aCopyDev for maior que zero, significa que          ³
	//³a operacao de troca foi feita pela rotina do menu LOJA720³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If Len(aCopyDev) > 0
		aDocDev := {}
		aDocDev := aClone(aCopyDev)
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Se for lAlterOrc esta com a opção de alteracao de orc    ³
	//³ entao a função de defpagto nao e chamada                ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	// Se a origem vier de pré-venda do uMov.me, vá para a primeira tela, dos itens.
	luMovmeOrig := SL1->(FieldPos("L1_UMOV"))>0 .And. Len(Alltrim(SL1->L1_UMOV))>0
	If (!lAlterOrc .OR. (!lAlterOrc .AND. lFtvdVer12)) .And. !luMovmeOrig
		ACTIVATE MSDIALOG oDlgVA ON INIT (Lj7SetKeys(.T.),oEncVA:SetFocus(),;
		IIf(nOpc == 4, Lj7DefPag(.F., @oPanVA3, aPosObj4, oEncVA, nOpc, @lTefPendCS, @aTefBKPCS, NIL, NIL, @nVlrAcrsFi, Nil, Nil, @aDadosCNeg), Nil), IIf(lFiscal .AND. nOpc == 4 .AND.LjMPreVend(SM0->M0_CGC),oGetVA:oBrowse:Disable(),Nil),LJ7NFTroca((Len(aCopyDev) > 0)) );
		VALID Lj7Sair( nOpc, nSaveSx8, aDocDev ,@lTefPendCS,;
					  @aTefBKPCS, lErroNFCe, @lErroNFe)
	ElseIf !lFtvdVer12 .OR. (lAlterOrc .AND. lFtvdVer12)
		ACTIVATE MSDIALOG oDlgVA ON INIT (Lj7SetKeys(.T.),oEncVA:SetFocus(),;
		IIf(nOpc == 4, NIL, Nil), IIf(lFiscal .AND. nOpc == 4 .AND.LjMPreVend(SM0->M0_CGC),oGetVA:oBrowse:Disable(),Nil),LJ7NFTroca((Len(aCopyDev) > 0)) );
		VALID Lj7Sair( nOpc, nSaveSx8, aDocDev ,@lTefPendCS,;
					  @aTefBKPCS, lErroNFCe, @lErroNFe)
	EndIf

Else
	//Tratamento do EXECAUTO

	LjGrvLog("","INICIO DO PROCESSO DE EXECAUTO",aCabAuto)

	//Valida/Monta o Cabeçalho do Orçamento
	For nX := 1 to Len(aCabAuto)
		aAdd(aValidGet,{aCabAuto[nX][1],aCabAuto[nX][2],"",.F.})
		AutoReadVar  := "M->" +Upper(AllTrim(aCabAuto[nX][1]))
		&AutoReadVar := aCabAuto[nX][2]
	Next nX

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³valida as informacoes de cabeçalho							 ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If !( lRet := MsVldGAuto(aValidGet) )
		Conout(STR0244) //"Erro na validação das informações do cabeçalho"

		LjGrvLog("","Erro na validação das informações do cabeçalho")

		Help( " ", 1, "Help",, STR0244, 1, 0 )
	Else
		aColsAux	:= aClone(aCols)

	 	aAdd( aColsDet, Array( Len(aHeaderDet)+1 ) ) //Inicializa o array aColsDet
		nPosDtItem	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_ITEM"})					// Posicao do numero do item
		nPosDtProd	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_PRODUTO"})					// Posicao do Codigo do produto
		nPosItem	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_ITEM"})][2]			// Posicao do numero do item
		nPosProd	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_PRODUTO"})][2]		// Posicao da codigo do produto

		LjGrvLog("","Iniciar validacao dos produtos",aItAuto)

		For nX := 1 to Len(aItAuto)
			For nY := 1 to Len(aItAuto[nX])
				//Descarto o numerador do Item para tratar pelo fonte
				If Alltrim(aItAuto[nX][nY][1]) == "LR_ITEM"
					Loop
				EndIf

				nPos := aScan(aHeader,{|x| Alltrim(x[2]) == Alltrim(aItAuto[nX][nY][1])})	// Procura a posicao do campo enviado na ExecAuto

				If nPos > 0
					aCols[nX][nPos] := aItAuto[nX][nY][2]
				Else
					// Pode ser que o campo enviado na ExecAuto seja no detalhe dos itens, por isso procura no AcolsDet
					nPos  := aScan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == Alltrim(aItAuto[nX][nY][1]) })
					If nPos > 0
	 					aColsDet[nX][nPos] := aItAuto[nX][nY][2]
					EndIf
				EndIf
			Next nY

			//Sequencia do item
			cItem := Soma1(cItem,nTamLR_ITEM)

			If (nPos := aScan(aHeader,{|x| Alltrim(x[2]) == "LR_ITEM" })) <> 0
				aCols[nX][nPos] := cItem
	   			aColsDet[nX][nPosDtItem] 	    := aCols[nX][nPosItem]
	   			aColsDet[nX][nPosDtProd] 	    := aCols[nX][nPosProd]
				If (nPos := aScan( aItAuto[nX], { |x| x[1] == "LR_ITEM" } )) > 0
					aItAuto[nX][nPos][2] 		:= aCols[nX][nPosItem]
				Else
					aAdd( aItAuto[nX], {"LR_ITEM", aCols[nX][nPosItem], NIL} )
				EndIf
			EndIf
				
			If nX < Len(aItAuto)
				aAdd(aCols		,aColsAux[1]	)
				aAdd(aColsDet, Array( Len(aHeaderDet)+1 ) ) //Adiciona uma posicao
			EndIf

			LjGrvLog("","CARREGOU O PRODUTO")
		Next nX
		
		_aItAuto	:= aItAuto	//guarda dados da ExecAuto para tratamentos de reserva LJ7Reserva  

		If !( lRet := MsGetDAuto(aItAuto,"Lj7LinOk",{|| .T. },aCabAuto,nOpc) )
			ConOut(STR0245) //"Erro validação Lj7LinOk"
			Help( " ", 1, "Help",, STR0245, 1, 0 )
			LjGrvLog("","ERRO VALIDACAO DA Lj7LinOk")
		Else
			LjGrvLog("","INCLUSAO DAS FORMAS DE PAGAMENTO",aPrcAuto)
			If isBlind()
				If lAutomato
					cItem := "  "
					For nX := 1 to Len(aItAuto)
						//Sequencia do item
						cItem := Soma1(cItem,nTamLR_ITEM)
						If (nPos := aScan(aHeader,{|x| Alltrim(x[2]) == "LR_ITEM" })) <> 0
							aCols[nX][nPos] := cItem
				   			aColsDet[nX][nPosDtItem] := aCols[nX][nPosItem]
						EndIf
					Next nX
				Endif
			Endif
			//Tratamento integracao Mensagem Unica para manter os valores de impostos
			If lIntegDef	
				For nX := 1 to Len(aItAuto)
					For nY := 1 to Len(aItAuto[nX])																						
						//CFOP
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_CF" 
							nPosDtCF := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_CF"}) //Posicao do CFOP
							aColsDet[nX][nPosDtCF] := aItAuto[nX][nY][2]
						EndIf
						
						//Valor ICMS
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_VALICM"
							nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_VALICM"}) //Posicao do Valor ICMS
							aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]
						EndIf
						
						//Base ICMS
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_BASEICM"
							nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_BASEICM"}) //Posicao da Base ICMS
							aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]
						EndIf
						
						//Aliquota ICMS
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_PICM"
							nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_PICM"}) //Posicao da Aliquota ICMS
							aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]
						EndIf
						
						//Valor ISS
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_VALISS"
							nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_VALISS"}) //Posicao do Valor de ISS
							aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]
						EndIf
						
						//Base ISS
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_BASEISS"
							nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_BASEISS"}) //Posicao da Base ISS
							aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]
						EndIf
											
						//Aliquota ISS
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_ALIQISS"
							nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_ALIQISS"}) //Posicao da Aliquota ISS
							aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]
						EndIf										
						
						//Valor PIS Apuracao
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_VALPS2"
							nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_VALPS2"}) //Posicao do PIS	Apuracao									
							aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]																			
						EndIf	
						
						//Base PIS Apuracao
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_BASEPS2"
							nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_BASEPS2"}) //Posicao da Base PIS Apuracao
							aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]
						EndIf
											
						//Aliquota PIS Apuracao
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_ALIQPS2"
							nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_ALIQPS2"}) //Posicao da Aliquota PIS Apuracao
							aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]
						EndIf	
																		
						//Valor PIS Retencao
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_VALPIS"
							nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_VALPIS"}) //Posicao do PIS Retencao										
							aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]																			
						EndIf	
						
						//Base PIS Retencao
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_BASEPIS"
							nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_BASEPIS"}) //Posicao da Base PIS Retencao
							aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]
						EndIf
											
						//Aliquota PIS Retencao
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_ALIQPIS"
							nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_ALIQPIS"}) //Posicao da Aliquota PIS Retencao
							aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]
						EndIf	
																																	
						//Valor COFINS Apuracao
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_VALCF2"
							nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_VALCF2"}) //Posicao do Cofins											
							aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]																			
						EndIf
						
						//Base COFINS Apuracao
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_BASECF2"
							nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_BASECF2"}) //Posicao da Base COFINS
							aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]
						EndIf
											
						//Aliquota COFINS Apuracao
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_ALIQCF2"
							nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_ALIQCF2"}) //Posicao da Aliquota COFINS
							aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]
						EndIf																																				
																														
						//Valor COFINS Retencao
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_VALCOFI"
							nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_VALCOFI"}) //Posicao do Cofins											
							aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]																			
						EndIf
						
						//Base COFINS Retencao
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_BASECOF"
							nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_BASECOF"}) //Posicao da Base COFINS
							aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]
						EndIf
											
						//Aliquota COFINS Retencao
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_ALIQCOF"
							nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_ALIQCOF"}) //Posicao da Aliquota COFINS
							aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]
						EndIf	
						
						//Valor CSLL
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_VALCSLL"
							nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_VALCSLL"}) //Posicao valor do CSLL											
							aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]																			
						EndIf
						
						//Base CSLL
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_BASCSLL"
							nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_BASCSLL"}) //Posicao base do CSLL											
							aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]																			
						EndIf
						
						//Aliquota CSLL
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_ALQCSLL"
							nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_ALQCSLL"}) //Posicao aliquota do CSLL											
							aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]																			
						EndIf
																		
						//Valor IRRF
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_VALIRRF"
							nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_VALIRRF"}) //Posicao valor do IRRF											
							aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]																			
						EndIf
						
						//Base IRRF
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_BASIRRF"
							nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_BASIRRF"}) //Posicao da Base IRRF
							aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]
						EndIf
											
						//Aliquota IRRF
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_ALQIRRF"
							nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_ALQIRRF"}) //Posicao da Aliquota IRRF
							aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]
						EndIf
						
						//Localização
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_LOCALIZ"
							nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_LOCALIZ"}) //Posicao da Localização
							aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]
						EndIf
							
							//Número de Série
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_NSERIE"
							nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_NSERIE"}) //Posicao do Número de Série
							aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]
						EndIf
							
						//Lote
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_LOTECTL"
							nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_LOTECTL"}) //Posicao do Lote
							aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]
						EndIf					

							//Sub-Lote
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_NLOTE"
							nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_NLOTE"}) //Posicao do SubLote
							aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]
						EndIf		
						
							//Filial da Reserva
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_FILRES"
							nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_FILRES"}) //Posicao do Filial da Reserva
							aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]
						EndIf
						
							//Data de Entrega
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_FDTENTR"
							nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_FDTENTR"}) //Posicao da Data de Entrega
							aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]
						EndIf
						
						//Valor FECP  
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_VALFECP"
							nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_VALFECP"}) //Posicao do valor FECP									
							aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]																			
						EndIf	
						
						//Base FECP
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_BASFECP"
							nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_BASFECP"}) //Posicao da Base FECP
							aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]
						EndIf
											
						//Aliquota FECP  
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_ALQFECP"
							nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_ALQFECP"}) //Posicao da Aliquota FECP
							aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]
						EndIf	
						
						//Valor FECP_ST  
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_VFECPST"
							nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_VFECPST"}) //Posicao do valor FECP_ST									
							aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]																			
						EndIf	
						
						//Base FECP_ST
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_BSFCPST"
							nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_BSFCPST"}) //Posicao da Base FECP_ST
							aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]
						EndIf
											
						//Aliquota FECP_ST
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_ALQFCST"
							nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_ALQFCST"}) //Posicao da Aliquota FECP_ST
							aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]
						EndIf
						
						//Aliquota IPI
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_IPI"
							nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_IPI"})
							aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]
						EndIf
						
						//Base IPI
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_BASEIPI"
							nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_BASEIPI"})
							aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]
						EndIf
						
						//Valor IPI
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_VALIPI"
							nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_VALIPI"})
							aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]
						EndIf
						
						//Aliquota ICMS Solidario (ICMS-ST)
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_ALIQSOL"
							nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_ALIQSOL"})
							aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]
						EndIf
						
						//Base ICMS Solidario (ICMS-ST)
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_BRICMS"
							nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_BRICMS"})
							aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]
						EndIf
						
						//Valor ICMS Solidario (ICMS-ST)
						If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_ICMSRET"
							nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_ICMSRET"})
							aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]
						EndIf
						
						If lIntegHtl //Integracao Hotelaria
							//Centro de Custo
							If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_CCUSTO"
								nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_CCUSTO"}) //Posicao de Centro de Custo
								aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]
							EndIf
							
							//Item Centro de Custo
							If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_ITEMCC"
								nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_ITEMCC"}) //Posicao de Item Centro de Custo
								aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]
							EndIf
							
							//Classe Valor
							If AllTrim(Upper(aItAuto[nX][nY][1])) == "LR_CLVL"
								nPosSLR := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_CLVL"}) //Posicao de Classe Valor
								aColsDet[nX][nPosSLR] := aItAuto[nX][nY][2]
							EndIf
						EndIf																																																														      
					Next nY
				Next nX
			EndIf
			
			//Realiza calculo do valor de desconto recebido
			If lAutoExec .AND. ( M->LQ_DESCONT > 0 .Or. M->LQ_DESCNF > 0 )
				Lj7VldDesc(Nil,M->LQ_DESCNF,M->LQ_DESCONT)
			EndIf

			If IsBlind()
				aPgtos	:= {}
			EndIf

			If !lFtvdVer12 .AND. !lECommerce .And. !lAutomato
				For nX := 1 to Len(aPrcAuto)

					aParcAux := aPrcAuto[nX]
					
					//Verifica se integracao com Hotel esta habilitada
					If lIntegDef										
						//Inicializa array com informacoes Tef da integracao Hotelaria
						aTefInteg := {}
						
						//Armazena Conta Hotel						
						cContaHtl := aPrcAuto[nX][aScan(aParcAux,{|x|  Alltrim(x[1]) == "L4_CONHTL"})][2]
						
						//Armazena informacoes Tef Hotel
						aAdd(aTefInteg, aPrcAuto[nX][aScan(aParcAux,{|x|  Alltrim(x[1]) == "L4_VENDTEF" })][2])
						aAdd(aTefInteg, aPrcAuto[nX][aScan(aParcAux,{|x|  Alltrim(x[1]) == "L4_DATATEF" })][2])
						aAdd(aTefInteg, aPrcAuto[nX][aScan(aParcAux,{|x|  Alltrim(x[1]) == "L4_HORATEF" })][2])
						aAdd(aTefInteg, aPrcAuto[nX][aScan(aParcAux,{|x|  Alltrim(x[1]) == "L4_DOCTEF"  })][2])
						aAdd(aTefInteg, aPrcAuto[nX][aScan(aParcAux,{|x|  Alltrim(x[1]) == "L4_AUTORIZ" })][2])
						aAdd(aTefInteg, aPrcAuto[nX][aScan(aParcAux,{|x|  Alltrim(x[1]) == "L4_DATCANC" })][2])
						aAdd(aTefInteg, aPrcAuto[nX][aScan(aParcAux,{|x|  Alltrim(x[1]) == "L4_HORCANC" })][2])
						aAdd(aTefInteg, aPrcAuto[nX][aScan(aParcAux,{|x|  Alltrim(x[1]) == "L4_DOCCANC" })][2])
						aAdd(aTefInteg, aPrcAuto[nX][aScan(aParcAux,{|x|  Alltrim(x[1]) == "L4_INSTITU" })][2])
						aAdd(aTefInteg, aPrcAuto[nX][aScan(aParcAux,{|x|  Alltrim(x[1]) == "L4_NSUTEF"  })][2])
						aAdd(aTefInteg, aPrcAuto[nX][aScan(aParcAux,{|x|  Alltrim(x[1]) == "L4_PARCTEF" })][2])											
					EndIf
					
					aAdd( aPgtos, {	aPrcAuto[nX][aScan(aParcAux,{|x|  Alltrim(x[1]) == "L4_DATA" })][2],;		//01 Data do orcamento
									aPrcAuto[nX][aScan(aParcAux,{|x|  Alltrim(x[1]) == "L4_VALOR"})][2],;		//02 Valor
									aPrcAuto[nX][aScan(aParcAux,{|x|  Alltrim(x[1]) == "L4_FORMA"})][2],;		//03 Forma de pagamento
					  				{ 	"",;
										"",;
					  					"",;
					  					"",;
					  					aPrcAuto[nX][aScan(aParcAux,{|x|  Alltrim(x[1]) == "L4_ADMINIS"})][2],;	//Administradora
					  					.T.,;
					  				},;																			//04 Array de parcelas
									dDataBase,;				   													//05 Data base
									1,;																			//06 Moeda
					               	aPrcAuto[nX][aScan(aParcAux,{|x|  Alltrim(x[1]) == "L4_DATA"})][2],;		//07 Data					               	
					               	aPrcAuto[nX][aScan(aParcAux,{|x|  Alltrim(x[1]) == "L4_FORMAID"})][2]})	//08 FormID
					               						               	
					If cPaisLoc == 'ARG'
						If SL4->(FieldPos("L4_CHEQID"))>0
							aAdd( aPgtos[nX], aPrcAuto[nX][aScan(aParcAux,{|x|  Alltrim(x[1]) == "L4_CHEQID" })][2])	//09 FormID
						Else
							aAdd( aPgtos[nX], " ")
						EndIf

						If SL4->(FieldPos("L4_VLMOED1"))>0
							aAdd( aPgtos[nX], aPrcAuto[nX][aScan(aParcAux,{|x|  Alltrim(x[1]) == "L4_VLMOED1"})][2])//10 FormID
						Else
							aAdd( aPgtos[nX], 0 )
						EndIf
					Else						
						aAdd( aPgtos[nX], dDataBase ) //09 DataBase MultiNegociacao
						aAdd( aPgtos[nX], 0 )         //10 Moeda MultiNegociacao
						aAdd( aPgtos[nX], 0 )         //11 Desconto MultiNegociacao
					EndIf
					
					//Adiciona informacoes integracao					
					If lIntegDef
						If (Trim(ATail(aPgtos)[3]) == "CH")
							ATail(aPgtos)[4] := {}
							
                            aAdd( ATail(aPgtos)[4], "" )
                            aAdd( ATail(aPgtos)[4], "" )
                            aAdd( ATail(aPgtos)[4], "" )
							aAdd( ATail(aPgtos)[4], aPrcAuto[nX][aScan(aParcAux,{|x|  Alltrim(x[1]) == "L4_ADMINIS"})][2] ) //"L4_ADMINIS"
							aAdd( ATail(aPgtos)[4], aPrcAuto[nX][aScan(aParcAux,{|x|  Alltrim(x[1]) == "L4_AGENCIA"})][2] ) //"L4_AGENCIA"
							aAdd( ATail(aPgtos)[4], aPrcAuto[nX][aScan(aParcAux,{|x|  Alltrim(x[1]) == "L4_CONTA"})][2] )  	//"L4_CONTA"
							aAdd( ATail(aPgtos)[4], aPrcAuto[nX][aScan(aParcAux,{|x|  Alltrim(x[1]) == "L4_NUMCART"})][2] ) //"L4_NUMCART"
							aAdd( ATail(aPgtos)[4], "" )                                                                    //"L4_COMP"
							aAdd( ATail(aPgtos)[4], aPrcAuto[nX][aScan(aParcAux,{|x|  Alltrim(x[1]) == "L4_RG"})][2] )  	//"L4_RG"
							aAdd( ATail(aPgtos)[4], aPrcAuto[nX][aScan(aParcAux,{|x|  Alltrim(x[1]) == "L4_TELEFON"})][2] ) //"L4_TELEFON"
							aAdd( ATail(aPgtos)[4], "" )
							aAdd( ATail(aPgtos)[4], aPrcAuto[nX][aScan(aParcAux,{|x|  Alltrim(x[1]) == "L4_TERCEIR"})][2] ) //"L4_TERCEIR"
							aAdd( ATail(aPgtos)[4], "" )
							aAdd( ATail(aPgtos)[4], "" )  //"L4_NOMECLI"
						EndIf
						
						aAdd( aPgtos[nX], cContaHtl)  //12 Conta Hotel
						aAdd( aPgtos[nX], aTefInteg ) //13 Informacoes de Tef Integracao				
					EndIf

					If cFrmAux <> Alltrim(aPrcAuto[nX][aScan(aParcAux,{|x|  Alltrim(x[1]) == "L4_FORMA"})][2]) .And. Empty(cFrmAux)
						cFrmAux := Alltrim(aPrcAuto[nX][aScan(aParcAux,{|x|  Alltrim(x[1]) == "L4_FORMA"})][2])
					ElseIf cFrmAux <> Alltrim(aPrcAuto[nX][aScan(aParcAux,{|x|  Alltrim(x[1]) == "L4_FORMA"})][2]) .And. !Empty(cFrmAux)
						cFrmAux := "CN"
					EndIf
				Next nX
			ElseIf lFtvdVer12 .OR. lECommerce .Or. lAutomato //Para e-Commerce tenho que passar por esta condicao, pois Lj7T_TotPar() faz os calculos no array global.
				Lj7T_TotPar( 2, 0 )

				For nX := 1 to Len(aPrcAuto)
					aParcAux   := aPrcAuto[nX]
					nPosDescMn := aScan(aParcAux,{|x|  Alltrim(x[1]) == "L4_DESCMN"}) //Posicao Desconto MultiNegociacao
					Lj7T_TotPar( 2, Lj7T_TotPar(2) + aPrcAuto[nX][aScan(aParcAux,{|x|  Alltrim(x[1]) == "L4_VALOR"})][2] )

					aAdd( aPgtos, {	aPrcAuto[nX][aScan(aParcAux,{|x|  Alltrim(x[1]) == "L4_DATA" })][2],;		//01 Data do orcamento
									aPrcAuto[nX][aScan(aParcAux,{|x|  Alltrim(x[1]) == "L4_VALOR"})][2],;		//02 Valor
									aPrcAuto[nX][aScan(aParcAux,{|x|  Alltrim(x[1]) == "L4_FORMA"})][2],;		//03 Forma de pagamento
					  				{ 	"",;
					  					"",;
					  					"",;
					  					"",;
					  					aPrcAuto[nX][aScan(aParcAux,{|x|  Alltrim(x[1]) == "L4_ADMINIS"})][2],;	//Administradora
					  					.T.,;
					  				},;																			//04 Array de parcelas
									dDataBase,;				   													//05 Data base
									1,;																			//06 Moeda
					               	aPrcAuto[nX][aScan(aParcAux,{|x|  Alltrim(x[1]) == "L4_DATA"})][2],;		//07 Data
					               	aPrcAuto[nX][aScan(aParcAux,{|x|  Alltrim(x[1]) == "L4_FORMAID"})][2],;	//08 FormID
					               	dDataBase,;	//09 DataBase MultiNegociacao
					               	0,;			//10 Moeda MultiNegociacao
					               	IIf(nPosDescMn > 0, aPrcAuto[nX][nPosDescMn][2], 0)})	//11 Desconto MultiNegociacao

                    //Tratamento aPagtos[X][4]
                    If  !( IsMoney(ATail(aPgtos)[3]) )

                    	ATail(aPgtos)[4] := {}
                         If  (Trim(ATail(aPgtos)[3]) == "CH")
                    		//A ordem do aCamposPrc não deverá ser alterada e as posições contendo espaços deverão ser mantidas.                        
                         	aCamposPrc := {"L4_DATA","L4_VALOR","L4_FORMA","L4_ADMINIS","L4_AGENCIA","L4_CONTA","L4_NUMCART","L4_COMP","L4_RG","L4_TELEFON","","L4_TERCEIR","","L4_NOMECLI"}
                         	For	nNum := 1 To Len(aCamposPrc) 
                         		nScanPrc := aScan(aParcAux,{|x|  Alltrim(x[1]) == aCamposPrc[nNum] })
                         		If nScanPrc > 0
                         			If aCamposPrc[nNum] $ "L4_NUMCART|L4_ADMINIS"
                         				aAdd( ATail(aPgtos)[4], aPrcAuto[nX][nScanPrc][2]) 
                         			Else
                         				aAdd( ATail(aPgtos)[4], IIF(!lAutomato,"",aPrcAuto[nX][nScanPrc][2]) )
                         			Endif
                         		Else
                         			aAdd( ATail(aPgtos)[4],"")
                         		EndIf
                         	Next
                        Else
                        	//A ordem do aCamposPrc não deverá ser alterada.
                        	aCamposPrc := {"L4_DATA","L4_VALOR","L4_FORMA","L4_NUMCART","L4_ADMINIS"}
                         	For	nNum := 1 To Len(aCamposPrc) 
                         		nScanPrc := aScan(aParcAux,{|x|  Alltrim(x[1]) == aCamposPrc[nNum] })
                         		If nScanPrc > 0
                         			If aCamposPrc[nNum] $ "L4_NUMCART|L4_ADMINIS"
                         				aAdd( ATail(aPgtos)[4], aPrcAuto[nX][nScanPrc][2]) 
                         			Else
                         				aAdd( ATail(aPgtos)[4], IIF(!lAutomato,"",aPrcAuto[nX][nScanPrc][2]) )
                         			Endif
                         		Else
                         			aAdd( ATail(aPgtos)[4],"")
                         		EndIf
                         	Next                        
                        EndIf
                                               
                    EndIf

					If cFrmAux <> Alltrim(aPrcAuto[nX][aScan(aParcAux,{|x|  Alltrim(x[1]) == "L4_FORMA"})][2]) .And. Empty(cFrmAux)
						cFrmAux := Alltrim(aPrcAuto[nX][aScan(aParcAux,{|x|  Alltrim(x[1]) == "L4_FORMA"})][2])
					ElseIf cFrmAux <> Alltrim(aPrcAuto[nX][aScan(aParcAux,{|x|  Alltrim(x[1]) == "L4_FORMA"})][2]) .And. !Empty(cFrmAux)
						cFrmAux := "CN"
					EndIf
				Next nX
			EndIf
			// Verifica se tem NCC caso o apgtos venha zerado
			If lAutomato .AND. M->LQ_CREDITO > 0 
				LJ7SeleNCC(4)
			EndIf
			LjGrvLog("","VALIDACAO DA CONDICAO DE PAGAMENTO")
			If (nPosLQ_CONDPG > 0) .AND. !( AllTrim(M->LQ_CONDPG) == AllTrim(aCabAuto[nPosLQ_CONDPG][2]))
				M->LQ_CONDPG := aCabAuto[nPosLQ_CONDPG][2]

			EndIf

			If Empty(M->LQ_CONDPG)
				aLj7CondPr := { 	1, ;
									cFrmAux,;
									{};
							}  
			Else
				aLj7CondPr := { 	2, ;
									M->LQ_CONDPG,;
									{};
							} 
			EndIf

			If  (lECommerce .And. !( Empty(aPgtos))) .Or. (lAutomato .And. !( Empty(aPgtos)))
				aXPgtos := AClone(aPgtos)  //Salva os pagamentos ja calculados pois Lj7CondPg() altera conforme a condicao, o que nao pode para o e-Commerce
			EndIf

			//Necessario para alimentar a variavel aAdmFinanc quando utilizada rotina de finalização em lote de orcamentos em ambiente NFCE
			If IsInCallStack("LJNFCELOT") .And. !(Len(aAdmFinanc) > 0)
				DbSelectArea("SAE")
				SAE->( DbSetOrder(1) )  //AE_FILIAL + AE_COD
				SAE->( DbSeek(xFilial("SAE")) )
			
				While SAE->AE_FILIAL == xFilial("SAE") .AND. SAE->( !Eof() )
					If !(AllTrim(SAE->AE_TIPO) $ MVCHEQUE .OR. IsMoney(SAE->AE_TIPO))
						If SX5->(DbSeek(xFilial("SX5")+"24"+AllTrim(SAE->AE_TIPO)))
			
							If (( nPosAE_MSBL > 0 .AND. SAE->AE_MSBLQL <> "1" ) .OR. nPosAE_MSBL == 0) .And. (!Alltrim(SAE->AE_TIPO) $ cMNFormPg)
								aAdd( aAdmFinanc, { AllTrim(SAE->AE_TIPO), SAE->AE_DESC, SAE->AE_COD } )
							EndIf
						EndIf
					EndIf
					DbSkip()
				EndDo
		    EndIf

			If lECCia .Or. !Empty(M->LQ_CODMNEG) 
				If nPosLQ_JUROS > 0 .AND. M->LQ_JUROS <> aCabAuto[nPosLQ_JUROS][2]
					M->LQ_JUROS :=  aCabAuto[nPosLQ_JUROS][2]
					M->LQ_TIPOJUR 	:= If(M->LQ_JUROS>0,1,0)
				EndIf
				
				If lECCia
					aLj7CondPr := {  1 ,;						//Tipo da condicao
									"CN",;	//Forma de pagto
									{IIF( M->LQ_TIPOJUR > 0,  Str(M->LQ_TIPOJUR,1), "") ,aXPgtos[1][1], aXPgtos[1][2], M->LQ_JUROS, M->LQ_PARCELA, 30, .T.} ;
									}
				EndIf
			EndIf

			Lj7CondPg( 	aLj7CondPr[1],;	//Tipo da condicao
						aLj7CondPr[2],;	//Forma de pagto
						aLj7CondPr[3],; //Dados para o calculo da condicao de pagamento
						.T.)			//Atualiza ListBox ou Apenas faz o calculo
															
			lRet := Lj7TudOk( Iif(lSalVen,2,1) )

			LjGrvLog("","RETORNO DA Lj7TudOk",lRet)

			If  (lECommerce .And. !( Empty(aXPgtos)))  .Or. (lAutomato .And. !( Empty(aPgtos)))
				aPgtos := AClone(aXPgtos)  //Restauro os pagamentos apos Lj7CondPg().
			EndIf

		EndIf
	EndIf
			
	LjGrvLog("","Vai chamar a finalizacao da ExecAuto")
	//Efetua a gravacao do orçamento no Venda Assistida
	If lRet
		//Foi disponibilizado Rotina ExecAuto para gravacao em modo venda somente para o cliente Piloto da NFC-e, utiliza PDV proprio		
		//Foi alterado da função LjNfGrvAuto para a funcao LjNFCeLot, para conseguir transmitir a NFC-e via em lote
		If lAutoExec .AND. (nOpc == 3 .AND. lSalVen) .AND. LjNfGrvAuto(SM0->M0_CGC) 
			Eval(bSalVen)
			LjGrvLog("","Retornou de Gravar como Venda")
		Else
			Eval(bSalOrc)
			LjGrvLog("","Retornou de Salvar como Orcamento")
		EndIf
	EndIf
EndIf

LjGrvLog("","Final da funcao do venda assitida "+Chr(10)+Chr(13)+Chr(10)+Chr(13))

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Desabilita SetKeys      									 ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
nCount2 := Len(aFuncoes)
For nCount1 := 1 To nCount2
	Lj7F_Menu(nCount1, .F.)
Next nCount1

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Chama a finalizacao da funcao fiscal                         ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If MaFisFound()
	MaFisEnd(.T.)
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Posiciona o orcamento para a MBrowse nao ficar "em branco"   ³
//³ no caso de finalizacao de orcamento com reserva em outra loja³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If nOpc == 3		// Inclusao
	SL1->(DbSetOrder(1))
	If !SL1->(DbSeek(xFilial("SL1")+M->LQ_NUM))
		SL1->(dbGoTo(nRegSL1))
	EndIf
ElseIf nOpc == 4		// Finaliza venda
	SL1->(dbGoTo(nRegSL1))
EndIf

Return .T.

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±³Funcao    ³Lj7MontaGD ³ Autor ³ Vendas Cliente       ³ Data ³ 22/06/02 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Monta aCols e aHeader da GetDados 						  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ void Lj7MontaGD(cExp1, aExp2, nExp3, aExp4, aExp5)         ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ cExp1 - Alias que sera carregado							  ³±±
±±³          ³ aExp2 - Array com os campos que devem ser carregados 	  ³±±
±±³          ³ nExp3 - Define qual e a opcao (Inclusao, alteracao ...)	  ³±±
±±³          ³ aExp4 - Array com os campos para montar o array de detalhe ³±±
±±³          ³         dos produtos                                       ³±±
±±³          ³ aExp5 - Array com os campos que podem ser alterados na     ³±±
±±³          ³ GetDados													  ³±±
±±³          ³ cExp6 - Filial do contrato (passada pelo SIGACRD)          ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Observacao³ Se for uma alteracao ira carrecar os itens da venda e      ³±±
±±³          ³ as formas de pagamento.                                    ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701 													  ³±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7MontaGD(cAlias	, aCpoGDa  	, nOpc		, aCpoGDaDet,;
					aAlterGD, cFilContra, nVlrAcrsFi)

Local aArea 	  	:= GetArea()						// Armazena area atual (alias, order e recno)
Local aTmpHeader	:= {}								// aHeader temporario
Local aTmpCols	 	:= {}  							    // aCols temporario
Local aCampos		:= {}								// Campos que serao utilizados no aCols
Local nCount1		:= 0								// Contador 1
Local nX 			:= 0								// Variavel auxiliar para controle de looping
Local nVlrSubTotal 	:= 0								// Variavel que contem o subTotal da venda
Local cX3_Valid		:= ""								// Variavel auxiliar para a montagem da GetDados
Local cCampo 		:= ""								// Variavel que carrega os campos do aCols
Local nItem			:= 0								// Contador dos itens da venda
Local nVlrParcelas	:= 0								// Valor das parcelas
Local nMoedaParc    := 1								// Moeda utilizada no SL4
Local nL2_VLRITEM 	:= 0								// Variavel para controle do valor total do item para adicionar na MaFisAdd
Local nL2_VLRUNIT 	:= 0								// Variavel para controle do valor unitario do item para adicionar na MaFisAdd
Local nL2_VALFRET 	:= 0								// Variavel para controle do valor unitario do frete
Local lRetCC		:= .T.								// Variavel para controle da impressao do item durante a concomitancia
Local lVAssConc	 	:= LjVassConc()						//Indica se o cliente utiliza a Vda Assistida Concomitante
Local aIcms         := {} 								// Array com o ICMS
Local nTamL4_FORMAID:= 0						 		// Tamanho do campo L4_FORMAID
Local nVlIpi 		:= 0								// Guarda valor de imposto para somar na hora de dar o display
Local nVlSol		:= 0
Local nVlItIPI		:= 0								// Guarda o valor do imposto no Item
Local cFilPesq		:= ""								// Filial a pesquisar
Local cFilAux		:= ""								// Filial a pesquisar utilizada dentro do while
Local cValCampo		:= ""								// Armazena o conteudo de cCampo
Local lMV_LOJKIT 	:= SuperGetMV("MV_LOJKIT", ,.F.)	//Parametro que indica se ira' utilizar ou nao o Kit de produtos
Local lLjPedVe		:= SuperGetMV("MV_LJPEDVE", NIL, .F.)	//Parametro que determina se utiliza a nova forma de Entrega
Local cMvDescSai	:= SuperGetMV("MV_DESCSAI",,"1")		// Desconto tratamento localizacoes
Local nTamL4_CHEQUEID := IIf(SL4->(ColumnPos("L4_CHEQID"))>0,TamSx3("L4_CHEQID")[1],1)	// Tamanho do campo L4_CHEQID - Localização Argentina
Local lSaveVisu		:= .F.								// Variavel para controlar se foi realizado uma visualizacao de orcamento no meio de uma venda
Local nCount        := 0                                // Numero de controle do item
Local cMVEstado 	:= SuperGetMV("MV_ESTADO",,"")  // parametro que indica o estado
Local nPosDtCF		:= 0
Local nVlrDesconto  := 0                                // Valor do desconto
Local nPosIPI       := 0
Local lCalcIPI      := .T.
Local nDescSufr     := 0                                    // Valor de Desconto Suframa
Local lUsaRegL2		:= .T.								//Se irá considerar registro do L2, quando PAF-ECF, necessário considerar registros excluídos
Local lRetaPaf		:= LjNfPafEcf(SM0->M0_CGC) .AND. !lMvljpdvpa // Sinaliza Retaguarda PAF-ECF, para realizar o tratamento da concomitancia, nao carrega deletados na visualizacao de orcamento finalizado
Local lTemDesPro 	:= .F.
Local cOrcRes		:= ""
Local cPedRes		:= ""
Local lCFRetPos 	:= .F.
Local lMultNeg		:= SuperGetMV("MV_LJMULTN",,.F.)  //MultNegociação está ativa?
Local lLjIcmJr		:= SuperGetMV("MV_LJICMJR",,.F.)  //Retirada do acréscimo da base de ICMS
Local lValePres		:= SL2->(ColumnPos("L2_VALEPRE")) > 0 .And. ExistFunc("Lj7VPNew") .And. Lj7VPNew()
Local lPafMd5		:= SL2->(ColumnPos("L2_PAFMD5")) > 0 .AND. !Empty(SL2->L2_PAFMD5)	// verifica se o campo L2_PAFMD5 existe na base e nao esta vazio
Local lECommerce 	:= SuperGetMV("MV_LJECOMM",,.F.) .AND. ( SL1->(ColumnPos("L1_ECFLAG")) > 0 .AND. (SL1->L1_ECFLAG == "1"))  //PEDIDO E-COMMERCE
Local lMvLjIPEn	 	:= SuperGetMV("MV_LJIPENP",, .F.)
Local nPrecoTab 	:= 0  //Preco de Venda do Produto
Local nIPIDesc 		:= 0 //Valor do IPI
Local nTotIPIDif	:= 0 //Valor do IPI diferente
Local nPosVrUnit	:= 0 // Posicao do Valor unitario
Local nPosVrItem	:= 0 // Posicao do Valor Item
Local nVlrAcrFin 	:= 0
Local nImpItCC		:= 1 // utilizado dentro da rotina LJ7ImpItCC para semaforo, pois deve ser aberto o cupom fiscal uma unica vez
Local aAreaTotal	:= {}
Local aAreaSL2		:= {}
Local cTpFrete		:= ""	// Tipo do Frete
Local nDescZF		:= 0	// valor de desconto do item referente ao SUFRAMA (Venda Direta)
Local lECCia 		:= SuperGetMv("MV_LJECOMO", .T., .F.)
//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
Local lFtvdVer12	:= LjFTVD()
Local cNomeProg		:= Iif(lFtvdVer12,"FATA701","LOJA701") 	//Nome da Rotina
Local nTotalSImp	:= 0	//Total sem impostos
Local lVisuFinal	:= .F.
Local lTemIPISol	:= .F.
Local lL2BASEIPI	:= SL2->(ColumnPos("L2_BASEIPI")) > 0

Default cFilContra	:= ""	// Filial do contrato, chamado do SIGACRD.
Default nVlrAcrsFi	:= 0

/*Se existir o campo devo validar se o conteúdo é preenchido, tem momentos que o SL2 não vem posicionado
isso ocorre no PDV PAF, orçamento já importado e clicado na opção "Finaliza Venda"; com isso trato 
se o campo está preenchido no banco*/
If lMvLjPdvPa .And. !Empty(AllTrim(SL1->L1_NUMORC))
	aAreaTotal := GetArea()
	DbSelectArea("SL2")
	aAreaSL2 := SL2->(GetArea())
	SL2->(DbSetOrder(1))
	//Nao ponho num laço, pois como é uma finalização de orçamento o primeiro item já tem que estar com o campo preenchido
	If SL2->(MsSeek(xFilial("SL1")+SL1->L1_NUM)) .And. !Empty(AllTrim(SL2->L2_PAFMD5))
		lPafMd5 := .T.
	Else
		lPafMd5 := .F.
	EndIf
	RestArea(aAreaSL2)
	RestArea(aAreaTotal)
EndIf

//Monta aHeader a partir dos campos do SX3
DbSelectArea("SX3")
SX3->( DbSetOrder(1) )
SX3->( MsSeek(cAlias) )

//Na visualizacao, nao carrega deletados de orcamento ja finalizado
If lRetaPaf .AND. nOpc == 2 .AND.( !Empty(SL1->L1_DOC) .OR. !Empty(SL1->L1_DOCPED) )
	lRetaPaf := .F.
EndIf

If lVisuSint
	nTamL4_FORMAID	:= TamSX3("L4_FORMAID")[1]
EndIf

If HasTemplate("PCL")
	AAdd(aCpoGDaDet,"LR_BICO")
	AAdd(aCpoGDa,"LR_LEGCOD")
EndIf

While !SX3->(Eof()) .AND. SX3->X3_ARQUIVO == cAlias

	If aScan(aCpoGDa, {|x| Upper(AllTrim(x)) == Upper(Alltrim(SX3->X3_CAMPO))}) > 0 .OR.;
		(SX3->X3_PROPRI $ "UT" .AND. CNIVEL >= SX3->X3_NIVEL .AND. X3Uso(SX3->X3_USADO))

		If aScan( aCpoGDa, { |x| AllTrim( x ) ==  AllTrim( SX3->X3_CAMPO ) } ) == 0
			aAdd( aCpoGDa, Alltrim(SX3->X3_CAMPO) )
			If SX3->X3_VISUAL <> "V"
				aAdd( aAlterGD, Alltrim(SX3->X3_CAMPO) )
			EndIf
		ElseIf !lFtvdVer12
			If SX3->X3_VISUAL == "V"
				If aScan( aAlterGD, { |x| AllTrim( x ) ==  AllTrim( SX3->X3_CAMPO ) } ) > 0
					aDel(aAlterGD, aScan( aAlterGD, Alltrim(SX3->X3_CAMPO) ))
					aSize(aAlterGD, Len(aAlterGD)-1)
				EndIf
			EndIf
		EndIf

		If HasTemplate("OTC")
			If Alltrim(SX3->X3_CAMPO) == "LR_CODGENE" .OR. Alltrim(SX3->X3_CAMPO) == "LR_RECEITA" .OR. Alltrim(SX3->X3_CAMPO) == "LR_CONJUNT" .OR. Alltrim(SX3->X3_CAMPO) == "LR_VENDAVU"
				If aScan( aAlterGD, { |x| AllTrim( x ) ==  AllTrim( SX3->X3_CAMPO ) } ) > 0
					aDel(aAlterGD, aScan( aAlterGD, Alltrim(SX3->X3_CAMPO) ))
					aSize(aAlterGD, Len(aAlterGD)-1)
				EndIf
			EndIf
		EndIf

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Critica se foi solicitado um campo que nao pertence ao Alias ³
		//³ da Getdados em questao										 ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If SX3->X3_ARQUIVO <> cAlias
			If !lAutoExec
				Aviso(	STR0008,; //"Inconsistencia"
						STR0009	+ CRLF +; //"No array da Getdados foram inseridos campos que nao pertencem"
						STR0010	+ CRLF +; //"ao Alias em questao. Este campo sera ignorado."
						STR0011 + aCpoGDa[nCount1] + STR0012 + cAlias,{STR0028}) //"Campo: "###" - Alias: " ### "OK"
			Else
				ConOut(	STR0008,;
						STR0009	+ CRLF +;
						STR0010	+ CRLF +;
						STR0011 + aCpoGDa[nCount1] + STR0012 + cAlias)
			EndIf
			Loop
		EndIf

		aAdd(aCampos	, AllTrim( SX3->X3_CAMPO ))

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Faz a checagem dos campos da aCols para ver se eh preciso    ³
		//³ fazer alguma validacao										 ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

		cX3_Valid := Alltrim(SX3->X3_VALID)

		If Alltrim(SX3->X3_CAMPO) == "D1_ITEM"
			cX3_Valid := .T.
		EndIf

		//Se a venda for concomitante ou Retaguarda PAF-ECF, não permitir a alteração de
		//nenhum dado na aCols após a digitação do produto, pois já foi impresso/registrado
		If lVAssConc .OR. lRetaPaf .OR. lPafMd5
			If !IsInCallStack("Lj7CpGrvOr") //Quando copia de orcamento nao valida alteracao de item
				If !Empty( Alltrim(cX3_Valid) )
					cX3_Valid := "Lj7VldAlIt()" + " .AND. " + cX3_Valid
				Else
					cX3_Valid := "Lj7VldAlIt()"
				EndIf
			Endif

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Quando for alteracao ele nao pode carregar a validacao da   ³
			//³funcao Lj7VldAlIt()										   ³
			//³A validacao e feita pela funcao Lj7ValidAt() antes de	   ³
			//³ inicia a rotina de altercao								   ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If lAlterOrc .AND. !lFtvdVer12
				cX3_Valid := ""
			EndIf
		Else
			If lMV_LOJKIT
				If Alltrim(SX3->X3_CAMPO) == "LR_PRODUTO"
					If !Empty( Alltrim(cX3_Valid) )
						cX3_Valid := "LjVldKIT()"+  ".AND." + cX3_Valid
					EndIf
				EndIf
			EndIf
			If lLjPedVe
				If AllTrim(SX3->X3_CAMPO) == "LR_ENTREGA"
					If Empty( Alltrim(cX3_Valid) )
						cX3_Valid := "LjVldEnt()"
					Else
						cX3_Valid := "LjVldEnt()" + " .AND. " + cX3_Valid
					EndIf
				EndIf
				If AllTrim(SX3->X3_CAMPO) == "LR_CODCONT"
					If Empty(Alltrim(cX3_Valid))
						cX3_Valid := "LjVldCnt()"
					Else
						cX3_Valid := "LjVldCnt()" + " .AND. " + cX3_Valid
					EndIf
				EndIf
			EndIf
		EndIf

		aAdd(aTmpHeader	,{	X3TITULO()	,;	//01 Titulo
							X3_CAMPO	,;	//02 Campo
							X3_PICTURE	,;	//03 Picture
							X3_TAMANHO	,;	//04 Tamanho
							X3_DECIMAL	,;	//05 Decimal
							cX3_Valid	,;	//06 Valid do campo
							X3_USADO	,;	//07 Se utilizado ou nao
							X3_TIPO		,;	//08 Tipo
							X3_ARQUIVO	,;	//09 Arquivo
							X3_CONTEXT 	})	//10 Conteudo
	EndIf

	SX3->(DbSkip())
End

If Len(aCpoGDa) = Len(aTmpHeader)
	aCpoGDa := {}
	For nX := 1 to Len(aTmpHeader)
		If !IsHeadRec( aTmpHeader[nX][2] ) .And. !IsHeadAlias( aTmpHeader[nX][2] )
			aAdd(aCpoGda, aTmpHeader[nX][2])
		EndIf
	Next nX
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Adiciona campos do Walk-Thru no aTmpHeader³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
AdHeadRec( "SL2", aTmpHeader )

If !lFtvdVer12
	SX3->(DbSetOrder(2))
	If SX3->(DbSeek("LR_VALIPI"))
	   nPosIPI := Ascan(aCpoGDaDet, "LR_VALIPI")
	   If !X3Uso(SX3->X3_USADO) .AND. nPosIPI > 0
	      aDel(aCpoGDaDet, nPosIPI)
	      aSize(aCpoGDaDet, Len(aCpoGDaDet)-1)
	   EndIf
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Monta aHeaderDet e aColsDet que contera os detalhes dos      ³
//³ produtos                                                     ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
SX3->(DbSetOrder(2))
For nX := 1 to Len(aCpoGDaDet)
	If SX3->(DbSeek( PadR(aCpoGDaDet[nX],10,"") ))
		cX3_Valid := Alltrim(SX3->X3_VALID)

		aAdd( aHeaderDet,{	X3TITULO()	,;	//01 Titulo
							X3_CAMPO	,;	//02 Campo
							X3_PICTURE	,;	//03 Picture
							X3_TAMANHO	,;	//04 Tamanho
							X3_DECIMAL	,;	//05 Decimal
							cX3_Valid	,;	//06 Valid
							X3_USADO	,;	//07 Usado
							X3_TIPO		,;	//08 Tipo
							X3_ARQUIVO	,;	//09 Arquivo
							X3_CONTEXT 	})	//10 Conteudo
	Else
		aAdd( aHeaderDet,{	"","","",0,0,"","","","","" } )
	EndIf

Next nX

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Prepara o array Private aPosCpo com as posicoes relativas	 ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Lj7PosRel(aCpoGDa, aCampos, aCpoGdaDet)

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Verifica se eh inclusao ou alteracao para criar um aCols     ³
//³ vazio ou recuperar um orcamento gravado                      ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If nOpc == 3
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Inicializa a parte fiscal³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
    If !MaFisFound("NF")
		lCalcIPI    := Ascan(aPosCpoDet,{|x| Alltrim(Upper(x[1])) == "LR_VALIPI"})	 > 0
		cTpFrete := Lj7TpFrete(M->LQ_CLIENTE,M->LQ_LOJA)
		cTpFrete	:= IIf( Empty(cTpFrete) .And. (M->LQ_TPFRET == "S" .OR. M->LQ_TPFRET == "0"), "S", cTpFrete)

		MaFisIni(	M->LQ_CLIENTE	,;	//01 Codigo Cliente/Fornecedor
					M->LQ_LOJA		,;	//02 Loja do Cliente/Fornecedor
					"C"				,;	//03 C:Cliente , F:Fornecedor
					"S"				,; 	//04 Tipo da NF
					Nil				,;	//05 Tipo do Cliente/Fornecedor
					Nil				,;	//06 Relacao de Impostos que suportados no arquivo
					Nil				,;	//07 Tipo de complemento
					.F.				,;	//08 Permite Incluir Impostos no Rodape .T./.F.
					"SB1"			,;	//09 Alias do Cadastro de Produtos - ("SBI" P/ Front Loja)
					cNomeProg       ,;	//10 Nome da rotina que esta utilizando a funcao
					Nil				,;	//11
					Nil				,;	//12
					Nil				,;	//13
					Nil				,;	//14
					Nil				,;	//15
					Nil				,;	//16
					Nil				,;	//17
					Nil				,;	//18
					Nil				,;	//19
					lCalcIPI		,;//20
					Nil				,;	//21
					Nil				,;	//22
					Nil				,;	//23
					Nil				,;	//24
					Nil				,; //25
					cTpFrete)	//26

		IF ExistFunc("LjSatMxFis")
			LjSatMxFis()
		EndIf

		If cPaisLoc == "ARG"
			MaFisLoad("NF_PROVENT", SM0->M0_ESTENT)
		EndIf
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Na inclusao monta o array com 1 elemento vazio               ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	aTmpCols := Array( 1, Len(aTmpHeader) + 1 )

	LjHeader(cAlias, aCpoGDa, @aTmpCols)

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Inicializa as variaveis ref.ao calculo de juros              ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	M->LQ_JUROS 	:= 0
	M->LQ_TIPOJUR 	:= 0

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Inicia com os valores padrão para o Walk-Thru³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	aTmpCols[1][ aScan( aTmpHeader, {|x| IsHeadRec( x[2] ) } ) ] := 0
	aTmpCols[1][ aScan( aTmpHeader, {|x| IsHeadAlias( x[2] ) } ) ] := "SL2"
	aTmpCols[1][ Len(aTmpHeader) + 1 ] := .F.

Else
	If !Empty(cFilContra)
		cFilPesq := cFilContra
	Else
		cFilPesq := xFilial("SL2")
	EndIf

	If nOpc == 2 .AND. MaFisFound("NF")
		MaFisSave()						// Guarda os dados da NF atual
		MaFisEnd()
		lSaveVisu := .T.
	EndIf

	/* Se for Visualizacao ou "Alt. Orcamento", setamos a variavel lEmiteNF (LOJA701A) como True,
	pois a MATXFIS a usa para carregar corretamente os valores da Excecao Fiscal */	
	If (nOpc == 2 .Or. aRotina[nOpc][1] == STR0235) .AND. (SL1->L1_IMPNF .or. nModulo == 5)
		LjNFFimVd(	.T.	 		 	, /*lEmiteCF*/	, /*lFinaliza*/ , /*cA1Est*/,;
					/*cA1Pessoa*/	, /*nRefLJ7087*/, /*lLJ7087*/	, 2,;
					.F.)
	EndIf

	//PAF-ECF: Para Retaguarda PAF-ECF, considerar os registros deletados que possuem MD5
	If lRetaPaf
		SET DELETED OFF
	EndIf

    //ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Se tem midia no orcamento carrega midia para variavel de memoria  ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If  AllTrim(Str(SuperGetMv("MV_LJRGMID",,0))) $ "1|2"
		If !Empty(SL1->L1_MIDIA)
			M->LQ_MIDIA := SL1->L1_MIDIA
		Endif
	Endif

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Quando for "alteracao" carrega os itens no aCols e aColsDet  ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If lFtvdVer12
		//antes de começar o trabalho na SL2, abrimos a SD2 e atribuimos o indice 3
		DbSelectArea("SD2")
		SD2->( DbSetOrder(3) )	//D2_FILIAL+D2_DOC+D2_SERIE+D2_CLIENTE+D2_LOJA+D2_COD+D2_ITEM
	EndIf

	nItem := 0
	DbSelectArea("SL2")
	SL2->( DbSetOrder(1) )
	SL2->( MsSeek(cFilPesq+SL1->L1_NUM) )
	
	lVisuFinal	:= (nOpc == 2 .And. (!Empty(SL1->L1_DOC) .Or. !Empty(SL1->L1_DOCPED)))
	lTemIPISol	:= (cPaisLoc == "BRA") .And. ( SL1->L1_VALIPI+SL1->L1_ICMSRET > 0 )
	nCount		:= 0

	While SL2->(!Eof()) .AND. SL2->L2_FILIAL+SL2->L2_NUM == cFilPesq+SL1->L1_NUM
		//PAF-ECF: Verifica se registro deletado será considerado
		If lRetaPaf
			lUsaRegL2 := !SL2->(Deleted()) .OR. ( SL2->(Deleted()) .AND. SL2->(ColumnPos("L2_PAFMD5")) > 0 .AND. !Empty(SL2->L2_PAFMD5) )
		EndIf

		If lUsaRegL2

			aAdd( aTmpCols, Array( Len(aTmpHeader) + 1 ) )
			nCount  := nCount + 1

			//Verifica se o produto eh Vale Presente
			If lValePres .And. nOpc == 4 //4=Finalizacao da Venda
				If !Empty( SL2->L2_VALEPRE )
					Lj7VPVdaVP(1) //Seta para indicar que eh venda de Vale Presente
				EndIf
			EndIf

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Inicializa a variavel para controle da impressao do item     ³
			//³ durante a venda concomitante                                 ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			lRetCC := .T.
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Carrega o aCols                                              ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			For nX := 1 to Len(aTmpHeader)
				cCampo := "L2_" + Alltrim(Substr(aTmpHeader[nX][2],4,Len(aTmpHeader[nX][2])))
			    If IsHeadRec( cCampo )
			    	aTmpCols[Len(aTmpCols)][nX] := SL2->(Recno())
			    ElseIf IsHeadAlias( cCampo )
			    	aTmpCols[Len(aTmpCols)][nX] := "SL2"
				ElseIf AllTrim(cCampo) == "L2_VLRITEM"
					aTmpCols[Len(aTmpCols)][nX] := ( FieldGet(ColumnPos(cCampo)) )
				ElseIf AllTrim(cCampo) == "L2_VRUNIT"
					aTmpCols[Len(aTmpCols)][nX] := SL2->L2_VRUNIT
				ElseIf AllTrim(cCampo) == "L2_REVLPRE" .AND. lUsaLstPre
					If SL2->(FieldPos("L2_REMLPRE")) > 0
						aTmpCols[Len(aTmpCols)][nX] := Lj843RtSYP(SL2->L2_REMLPRE)
				    EndIf
				ElseIf AllTrim(cCampo) == "L2_MSGLPRE" .AND. lUsaLstPre
					If SL2->(FieldPos("L2_MSMLPRE")) > 0
						aTmpCols[Len(aTmpCols)][nX] := Lj843RtSYP(SL2->L2_MSMLPRE)
				    EndIf
				Else
					// Posicao 10 do aTmpHeader igual conteudo extraido do SX3->X3_CONTEXT
					If aTmpHeader[nX][10] == "V"
						aTmpCols[Len(aTmpCols)][nX] := CriaVar( cCampo, .T. )
					Else
						aTmpCols[Len(aTmpCols)][nX] := FieldGet(ColumnPos(cCampo))
					Endif
				EndIf

			Next nX

			//PAF-ECF: Sinaliza quando registro excluído
			If (lRetaPaf .AND. SL2->(Deleted())) .Or. (!lVAssConc .And. lMvLjPdvPa .And. SL2->L2_VENDIDO=="N")
				aTmpCols[Len(aTmpCols)][Len(aTmpHeader) + 1] := .T.
			Else
		        aTmpCols[Len(aTmpCols)][Len(aTmpHeader) + 1] := .F.
		    EndIf

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Carrega o aColsDet                                           ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			aAdd( aColsDet, Array( Len(aCpoGDaDet) + 1 ) )
			For	nX := 1 to Len(aCpoGDaDet)

				cCampo := "L2_" + Alltrim(Substr(aCpoGDaDet[nX],4,Len(aCpoGDaDet[nX])))

				If AllTrim(cCampo) == "L2_VLRITEM"
					aColsDet[Len(aColsDet)][nX] := ( FieldGet(ColumnPos(cCampo)) + L2_DESCPRO )
				ElseIf AllTrim(cCampo) == "L2_VRUNIT"
					aColsDet[Len(aColsDet)][nX] := SL2->L2_VRUNIT
				ElseIf AllTrim(cCampo) == "L2_TABELA"
		  			cValCampo := FieldGet(ColumnPos(cCampo))

					If SB0->(ColumnPos("B0_PRV" + cValCampo) )	> 0
						aColsDet[Len(aColsDet)][nX] := cValCampo
					Else
						aColsDet[Len(aColsDet)][nX] := "1"
					EndIf
				Else
					aColsDet[Len(aColsDet)][nX] := FieldGet(ColumnPos(cCampo))
				EndIf

			Next nX

			//PAF-ECF: Sinaliza quando registro excluído
			If (lRetaPaf .AND. SL2->(Deleted())) .Or. (!lVAssConc .And. lMvLjPdvPa .And. SL2->L2_VENDIDO=="N")
				aColsDet[Len(aColsDet)][Len(aCpoGDaDet) + 1] := .T.
			Else
				aColsDet[Len(aColsDet)][Len(aCpoGDaDet) + 1] := .F.
			EndIf

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Inicializa as funcoes fiscais                                ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	        If !MaFisFound("NF")
	        	lCalcIPI := Ascan(aPosCpoDet,{|x| Alltrim(Upper(x[1])) == "LR_VALIPI"})	 > 0
				cTpFrete := Lj7TpFrete(M->LQ_CLIENTE,M->LQ_LOJA)
				cTpFrete := IIf( Empty(cTpFrete) .And. (M->LQ_TPFRET == "S" .OR. M->LQ_TPFRET == "0"), "S", cTpFrete)

				MaFisIni(	M->LQ_CLIENTE	,;	//01 Codigo do cliente
							M->LQ_LOJA		,;	//02 Loja
							"C"				,;	//03 Cliente ou Fornecedor
							"S"				,;	//04 Tipo da Nota Fiscal
							M->LQ_TIPOCLI	,;	//05 Tipo de Cliente/Fornecedor
							Nil				,;	//06 Relacao de Impostos que suportados no arquivo
							Nil				,;	//07 Tipo de complemento
							.F.				,;	//08 Permite Incluir Impostos no Rodape .T./.F.
							"SB1"			,;	//09 Alias do Cadastro de Produtos - ("SBI" P/ Front Loja)
							cNomeProg      ,;	//10 Nome da rotina que esta utilizando a funcao
							Nil				,;	//11
							Nil				,;	//12
							Nil				,;	//13
							Nil				,;	//14
							Nil				,;	//15
							Nil				,;	//16
							Nil				,;	//17
							Nil				,;	//18
							Nil				,;	//19
							lCalcIPI		,;	//20
							Nil				,;	//21
							Nil				,;	//22
							Nil				,;	//23
							Nil				,;	//24
							Nil				,;	//25
							cTpFrete		)	//26
				
				IF ExistFunc("LjSatMxFis")
					LjSatMxFis()
				EndIf
			EndIf

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Chama as funcoes fiscais                                     ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If MaFisFound("NF")
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³ Faz um tratamento especifico para visualizacao de orcamentos.³
				//³ Como o loja manipula os valores dos itens referents a descon-³
				//³ tos e acrescimos, temos que recalcular o desconto financeiro ³
				//³ antes de mostrar o orcamento na tela.                        ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	            If nOpc == 2

	            	If cPaisLoc == "BRA"
	            		/*
	            			Tratamento especifico para VISUALIZAÇAO de Vendas FINALIZADAS emitidas pelo VENDA DIRETA com SUFRAMA.
	            			Esse tratamento é necessário, pois como o valor do Suframa é obtido em tempo de execução com base no valor do item,
	            			quando a venda é finalizada, o valor do item é subtraido do valor do suframa, entao vamos até a SD2 e recuperamos esse valor
	            		*/
	            		If lFtvdVer12 .AND. !Empty(SL1->L1_DOC) .AND. !Empty(SL1->L1_SERIE)
	            			If MaFisRet(,"NF_SUFRAMA")
	            				nDescZF := Posicione( "SD2", 3, xFilial("SD2")+SL2->L2_DOC+SL2->L2_SERIE+SL1->L1_CLIENTE+SL1->L1_LOJA+SL2->L2_PRODUTO+SL2->L2_ITEM, "D2_DESCZFR" )
	            			EndIf
	            		EndIf

	            		If !aTmpCols[Len(aTmpCols)][Len(aTmpHeader) + 1]
			            	nL2_VLRITEM := SL2->L2_VLRITEM + SL2->L2_DESCPRO + SL2->L2_VALDESC + nDescZF
	            		EndIf

			            //zeramos a variavel com o valor do desconto do Suframa
			            nDescZF := 0

	            	Else
						//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
						//³Para localizacoes, necessario verificar antes do parametro      ³
						//³pois se estiver como 1, o nL2_VLRITEM deve estar sem o desconto.³
						//³Se estiver como 2, considera o desconto (calculos da MATXFIS)   ³
						//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	            		If cMvDescSai == "1"
			            	nL2_VLRITEM :=	SL2->L2_VLRITEM
	            		ElseIf cMvDescSai == "2"
							nL2_VLRITEM := SL2->L2_VLRITEM + SL2->L2_VALDESC + SL2->L2_DESCPRO
	            		EndIf
	            	EndIf
				Else
					nL2_VLRITEM := SL2->L2_VLRITEM + SL2->L2_VALDESC + SL2->L2_DESCPRO
				EndIf

				If SL2->L2_DESCPRO > 0
           			lTemDesPro := .T.
           		EndIf

				nL2_VLRUNIT := nL2_VLRITEM / SL2->L2_QUANT
				nL2_VALFRET	:= IIf( nOpc <> 2 , SL2->L2_VALFRE , 0 )

				//Ajusta valores do aCols
				If nOpc <> 2
					nPosVrUnit	:= aPosCpo[Ascan(aPosCpo,{|x| Alltrim(Upper(x[1])) == "LR_VRUNIT"})][2]	// Posicao do Valor unitario
					nPosVrItem	:= aPosCpo[Ascan(aPosCpo,{|x| Alltrim(Upper(x[1])) == "LR_VLRITEM"})][2]	// Posicao do Valor do Item
					If nPosVrItem > 0 .And. nPosVrUnit > 0
						aTmpCols[Len(aTmpCols)][nPosVrItem] := nL2_VLRITEM - SL2->L2_VALDESC
						aTmpCols[Len(aTmpCols)][nPosVrUnit] := aTmpCols[Len(aTmpCols)][nPosVrItem] / SL2->L2_QUANT
					EndIf
				EndIf

				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³ Adiciona as variaveis nas funcoes fiscais                    ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

				//PAF-ECF: Desliga deletados para não considerar produtos e TES deletados
				If lRetaPaf
					SET DELETED ON
				EndIf

				SB1->(DbSetOrder(1))
				SB1->(DbSeek(xFilial("SB1")+SL2->L2_PRODUTO))

				SF4->(DbSetOrder(1))
	    		SF4->(DbSeek(xFilial("SF4")+SL2->L2_TES))

				MaFisIniLoad(nCount, ;
							{SL2->L2_PRODUTO,;	//IT_PRODUTO
							SL2->L2_TES,; 		//IT_TES
							SB1->B1_CODISS,; 	//IT_CODISS
							SL2->L2_QUANT,;		//IT_QUANT
							"",; 				//IT_NFORI
							"",; 				//IT_SERIORI
							SB1->(RecNo()),;	//IT_RECNOSB1
							SF4->(RecNo()),;	//IT_RECNOSF4
							0  }) 				//IT_RECORI

				IF ExistFunc("LjSatMxFis")
					LjSatMxFis()
				EndIf							

				MaFisLoad("IT_VALMERC"	,nL2_VLRITEM	,nCount)
				MaFisLoad("IT_PRCUNI"	,nL2_VLRUNIT	,nCount)

				If cPaisLoc == "BRA"
					If lVisuFinal .And. lTemIPISol .And. SL1->L1_DESCONT > 0
						MaFisLoad("IT_DESCTOT"	, SL2->L2_DESCPRO ,nCount)
						MaFisLoad("IT_TOTAL"	, SL2->L2_PRCTAB + SL2->L2_ICMSRET + SL2->L2_VALIPI , nCount )
						MaFisLoad("IT_BASESOL"	, SL2->L2_BRICMS , nCount )
						MaFisLoad("IT_VALSOL"	, SL2->L2_ICMSRET, nCount )
						MaFisLoad("IT_VALIPI"	, SL2->L2_VALIPI , nCount )
						If lL2BASEIPI .And. (SL2->L2_BASEIPI > 0)
							MaFisLoad("IT_BASEIPI", SL2->L2_BASEIPI , nCount )
						EndIf
					Else
						MaFisLoad("IT_DESCONTO"	,SL2->L2_VALDESC,nCount)
					EndIf
				Else
					MaFisLoad("IT_DESCONTO"	,SL2->L2_VALDESC+SL2->L2_DESCPRO,nCount)
				EndIf
				
				MaFisLoad("IT_FRETE"	,nL2_VALFRET 	,nCount)
				MaFisLoad("IT_SEGURO"	,SL2->L2_SEGURO ,nCount)
				MaFisLoad("IT_DESPESA"	,SL2->L2_DESPESA,nCount)

				If cPaisLoc == "ARG" .AND. (Ascan(aPosCpo,{|x| Alltrim(Upper(x[1])) == "LR_PROVENT"}) > 0)
					MaFisLoad("IT_PROVENT",SL2->L2_PROVENT,nCount)
				EndIf

				MaFisRecal("",nCount)

				If cPaisLoc == "BRA"
					MaFisEndLoad(nCount,2)
				Else
					MaFisEndLoad(nCount,1)
				EndIf
				
				//PAF-ECF: Re-Liga deletados
				If lRetaPaf
					SET DELETED OFF
				EndIf
			EndIf

			//Tratamento para IPI Embutido e-commerce - VISUALIZACAO
			If nOpc == 2 .AND. lECommerce .AND. lMvLjIPEn .AND. !lECCia
				SF4->( DbSetOrder( 1 ) )

				If !Empty(cFilContra)
					cFilAux := cFilContra
				Else
					cFilAux := xFilial("SF4")
				EndIf

				If SF4->( DbSeek( cFilAux + SL2->L2_TES ) )  .AND. SF4->F4_IPI == "S"
				    nPrecoTab := 0
				    nIPIDesc := 0
					LjxeValPre(@nPrecoTab, 	SL2->L2_PRODUTO, SL1->L1_CLIENTE , SL1->L1_LOJA,;
								nMoedaCor   , SL2->L2_QUANT , , @nIPIDesc,;
								.T. )
					nIPIDesc *= SL2->L2_QUANT
					If (nPrecoTab == nL2_VLRUNIT) .AND.  nIPIDesc <> 0
						MaFisAlt("IT_VALIPI" ,nIPIDesc,nCount)
					EndIf
				EndIf
			EndIf

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Se estiver configurado para fazer a concomitancia, faz a im- ³
			//³ pressao dos itens no ECF. Nao faz este controle quando for   ³
			//³ visualizacao                                                 ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			//PAF-ECF: Passando param L2_VENDIDO para sinalizar item cancelado na geração do orçamento(DAV)

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//|Se for Finalizacao de Venda, recuperamos o acrescimo salvo no orcamento,				|
			//| pois ao finalizar um orcamento com acrescimo financeiro passivel de arredondamento,	|
			//|o sistema arredondava o acrescimo, mesmo estando configurado para truncar os valores	|
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If nOpc == 4
				nVlrAcrsFi += SL2->L2_VALACRS
			EndIf

			cOrcRes	:= SL1->L1_ORCRES	// Codigo do orcamento da reserva
			cPedRes	:= SL1->L1_PEDRES	// Codigo do pedido da reserva
			lCFRetPos := Empty(cPedRes) .And. !Empty(cOrcRes) .And. ExistFunc("Lj140ImpOrc") //Verifica se eh orcamento (com itens de RETIRA POSTERIOR) apenas para finalizacao (impressao do Cupom Fiscal)

			If nOpc <> 2 .AND. lVAssConc .AND. !SL2->L2_ENTREGA $("13") .AND. !lRetaPaf .And. !lIsPafNfce .And. (!lValePres .Or.( Lj7VPYesNo() <> "S"))
				lRetCC := LJ7ImpItCC( Len(aTmpCols), aTmpCols, aTmpHeader, aIcms , .T., SL2->L2_VENDIDO,nImpItCC )
				nImpItCC+=1 // utilizado dentro da rotina LJ7ImpItCC para semaforo, pois deve ser aberto o cupom fiscal uma unica vez
			EndIf

			If lRetCC .AND. !(lRetaPaf .AND. SL2->(Deleted())) .And. !SL2->L2_VENDIDO=="N"
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³ Incrementa a variavel com o subtotal da venda.               ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				nItem++
				
				If lVisuFinal //Nao recalcular total na visualizacao de orcamento finalizado
					If lTemIPISol .And. (SL1->L1_DESCONT > 0)
						nVlrSubTotal += SL2->L2_PRCTAB + SL2->L2_ICMSRET + SL2->L2_VALIPI
                    Else
                    	nVlrSubTotal += MaFisRet( nItem, "IT_TOTAL" )
                    EndIf
                Else
                    nVlrSubTotal += MaFisRet( nItem, "IT_TOTAL" ) - Iif( lFtvdVer12 .And. nOpc == 4 , MaFisRet( nItem, "IT_FRETE" ) , 0 )
                EndIf
				
				nVlrDesconto += MaFisRet( nItem, "IT_DESCONTO" )
				
				If cPaisLoc == "MEX" .AND. cMvDescSai == "1"
					nVlrSubTotal := nVlrSubTotal - nVlrDesconto
				EndIf
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Se existir IPI liquido, deve abater do IPI de cada um dos itens³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				nVlItIPI := MaFisRet( nItem, "IT_VALIPI" )
				If nVlItIPI > 0
					SF4->( DbSetOrder( 1 ) )

					If !Empty(cFilContra)
						cFilAux := cFilContra
					Else
						cFilAux := xFilial("SF4")
					EndIf

					If SF4->( DbSeek( cFilAux + MaFisRet( nItem, "IT_TES" ) ) )      
						//Tratamento para IPI Embutido e-commerce - VISUALIZACAO
					 	If lECommerce .AND. lMvLjIPEn .AND. !lAutoExec .and. !lECCia
						    nPrecoTab := 0
						    nIPIDesc := 0
							LjxeValPre(@nPrecoTab, 	+SL2->L2_PRODUTO, M->LQ_CLIENTE , M->LQ_LOJA,;
										nMoedaCor   , +	SL2->L2_QUANT , , @nIPIDesc,;
										.T. )
							nIPIDesc *= SL2->L2_QUANT
							If nIPIDesc  <> nVlItIPI
								nVlrSubTotal -= nVlItIPI
								nVlrSubTotal += nIPIDesc
							EndIf
						EndIf
					EndIf

				EndIf

				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³A linha acima foi altera devido a uma diferenca de centavos qdo utilizada                   ³
				//³a funcao fiscal para fazer pedidos.                                                         ³
				//³Exemplo:                                                                                    ³
				//³Fazer uma venda de 2 produtos com substituição trib.                                        ³
				//³                                                                                            ³
				//³   qtd  prcunit  total                                                                      ³
				//³1)  1 x 18.90 = 22,75 (valor jah com impostos)                                              ³
				//³2)  1 x 61,00 = 75,00 (valor jah com impostos)                                              ³
				//³Total = 97,75                                                                               ³
				//³                                                                                            ³
				//³Se vender soh o item 2                                                                      ³
				//³2)  1 x 61,00 = 74,99                                                                       ³
				//³                                                                                            ³
				//³A diferença fica se for feito um pedido com o exemplo 1 sendo o                             ³
				//³primeiro item reservado na mesma loja e o 2o com reserva na                                 ³
				//³loja 02.                                                                                    ³
				//³Aih quando for finalizar a venda do orçamento na loja 02 vai ficar com R$0,01 de diferenca. ³
				//³                                                                                            ³
				//³O tratamento acima foi incluido para pegar os valores jah gravados quando for finalizacao   ³
				//³da venda de um orcamento "filho" e nao mais pegar da MaFisRet                               ³
				//³                                                                                            ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			Else
				If nCount > 0
					nItem ++ // Deve-se somar mais um pois na visualizacao do orcamento não soma todos os valores de item
				EndIf
				MafisDel(Len(aTmpCols),.T.)
			EndIf
        EndIf

		DbSelectArea("SL2")
		SL2->( DbSkip() )
	End

	If cPaisLoc <> "BRA"
		nX:= 1
		While MaFisFound("IT",nX)
			MaFisEndLoad(nX,1)
			nX++
		End
		nVlrSubTotal := MaFisRet( Nil, "NF_TOTAL" )
	EndIf

	//PAF-ECF: Desliga deletados
	If lRetaPaf
		SET DELETED ON
	EndIf

	If lSaveVisu
		MaFisRestore()		// Restaura os dados da venda
	EndIf
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Caso for finalizacao e tiver permissao para aletara o 		³
	//³ documento fiscal ( nota/cupom ) atualiza o CFOP dos produtos³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If nOpc == 4 .AND. LjNfAltDoc(SM0->M0_CGC)
		DbSelectArea("SA1")
		DbSetOrder(1)
		If DbSeek(xFilial("SA1") + M->LQ_CLIENTE + M->LQ_LOJA)
			If cMVEstado <> SA1->A1_EST
				nPosDtCF := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_CF"})					// Posicao do Codigo do CF

				For nX := 1 To Len(aColsDet)
					aColsDet[nX][nPosDtCF] := MaFisRet(nX,"IT_CF")
				Next nX
			EndIf
        EndIf
    EndIf
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Se houver apenas um item, estiver configurado para concomi-  ³
	//³ tancia e o item nao foi impresso corretamente, cria uma aCols³
	//³ zerada como se fosse selecionada a opcao de Atendimento      ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	//PAF-ECF: Nao deve realizar quando Retaguarda PAF-ECF
	If lVAssConc .AND. !lRetaPaf
		If Len(aTmpCols) == 1 .AND. aTmpCols[1][Len(aTmpCols[1])]
			aTmpCols := Array( 1, Len(aTmpHeader) + 1 )
			aTmpCols[Len(aTmpCols)][Len(aTmpHeader) + 1] := .F.
			LjHeader(cAlias, aCpoGDa, @aTmpCols)
		EndIf
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Qdo "alteracao" carrega as formas de pagamento               ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	aPgtos 			:= {}
	aPgtosSint  	:= {}
	nVlrParcelas 	:= 0

	If !Empty(cFilContra)
		cFilAux := cFilContra
	Else
		cFilAux := xFilial("SL4")
	EndIf

	DbSelectArea("SL4")
	SL4->( DbSetOrder(1) )
	SL4->( DbSeek(cFilAux+SL1->L1_NUM) )
	While SL4->(!Eof()) .AND. SL4->L4_FILIAL + SL4->L4_NUM == cFilAux + SL1->L1_NUM

		If Empty(SL4->L4_ORIGEM)
			aAdd( aPgtos, {	SL4->L4_DATA							 ,;	//01 Data do orcamento
							SL4->L4_VALOR							 ,;	//02 Valor
							SL4->L4_FORMA							 ,;	//03 Forma de pagamento
							{}										 ,;	//04 Array de parcelas
							NIL										 ,;	//05 Data base
							IIf(cPaisLoc<>"BRA",SL4->L4_MOEDA,NIL)	 ,;	//06 Moeda
			               	IIf(cPaisLoc<>"BRA",SL4->L4_DATA,NIL)	 ,;	//07 Data
			               	If(lVisuSint,SL4->L4_FORMAID,Space(01)) ,;	//08 FormID
			               	Space(nTamL4_CHEQUEID) ,;					//09 ChequeID
			               	If(SL4->(ColumnPos("L4_VLMOED1")) > 0,SL4->L4_VLMOED1,0)	}) //10 Valor da moeda 1

			//Ao alterar o Orçamento o valor do acrescimo financeiro será considerado caso o parametro MV_LjIcmJr estiver .F.
			//caso ele esteja ativo o acrescimo devera ser destacado apenas na posição 9 do aPgtos para que seja gravado no campo L4_ACRSFIN
			If cPaisLoc == "BRA" .And. lMultNeg .AND. !lLjIcmJr
				aPgtos[Len(aPgtos)][2] += SL4->L4_ACRSFIN
				nVlrParcelas += SL4->L4_ACRSFIN
				nVlrAcrFin += SL4->L4_ACRSFIN
			else
				aPgtos[Len(aPgtos)][9] := SL4->L4_ACRSFIN
			EndIf

			If cPaisLoc <> "BRA"
			   nMoedaParc  := SL4->L4_MOEDA
			EndIf
			nVlrParcelas += Round(xMoeda(SL4->L4_VALOR - SL4->L4_TROCO,nMoedaParc,nMoedaCor,dDatabase,nDecimais+1,,nTxMoeda),nDecimais)
		EndIf
		SL4->(DbSkip())
	End

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Se nao foi gravada as condicoes de pagto nao permite que     ³
	//³ inicialize o aPgtos vazio                                    ³
	//³ Array para o objeto oPgtos	                                 ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If Empty(aPgtos)
	   aPgtos 		:= {{	Ctod(Space(8))							   		,;	//01 Data orcamento
	   						0										   		,;	//02 Valor
	   						Space(2)								   		,;	//03 Forma de pagamento
	                       	{}										   		,;	//04 Array de parcelas
	                       	NIL										   		,;	//05 Data
	                       	IIf(cPaisLoc<>"BRA",nMoedaCor,NIL)				,;	//06 Moeda
	                       	IIf(cPaisLoc<>"BRA",Ctod(Space(8)),NIL)		,;	//07 Data
	                       	If(lVisuSint,Space(nTamL4_FORMAID),Space(01))	,;	//08 FormID
							Space(nTamL4_CHEQUEID) ,;							//09 ChequeID
	                       	0										 	  }}	//10 Valor da moeda 1

	   aPgtosSint 	:= { {	Space(02)												,;	//01 Forma de pagato
	   						0														,;	//02 Qtde de parcelas
	                       Transform(0,PesqPict("SL4","L4_VALOR",NIL,nMoedaCor))	,;	//03 Valor
	                       If(lVisuSint,Space(nTamL4_FORMAID),Space(01)) 			,;	//04 FormID
	                       Ctod(Space(8))                                       	,;	//05 Data
	                       {}  		                           						,;	//06 Array de parcelas
	                       Space(nTamL4_CHEQUEID) ,;									//07 ChequeID
	                       0	} }														//08 Valor da moeda 1
    EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Carrega as variaveis ref. ao calculo dos juros               ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	M->LQ_JUROS 	:= SL1->L1_JUROS
	M->LQ_TIPOJUR	:= SL1->L1_TIPOJUR

	If M->LQ_TPFRET == "S"  // Sem Frete
		M->LQ_TPFRET := "0"
	ElseIf M->LQ_TPFRET == "C"  // CIF
		M->LQ_TPFRET := "1"
	ElseIf M->LQ_TPFRET == "F"  // FOB
		M->LQ_TPFRET := "2"
	EndIf
	cOldTpFrete := M->LQ_TPFRET

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Acerta as variaveis de desconto                              ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	aDesconto := { Val(SL1->L1_TIPODES), SL1->L1_DESCNF, SL1->L1_DESCONT }

	If cPaisLoc == "MEX"
		If (nOpc == 2 .Or. nOpc == 4) .And. !Empty(SL1->L1_SITUA) .And. !lTemDesPro .And. aDesconto[03] > 0
			nVlrSubTotal -= aDesconto[03]
		EndIf
	EndIf

	Lj7T_DescV( 2, aDesconto[03] )
	
	/*Dentro da função Lj7T_DescV, há alteração da referência NF_DESCTOT dai se 
	houver desconto, IPI e Solidário os valores	são totalmente alterados na MatxFis, 
	portanto ajusto esses valores no subtotal*/
	If lTemIPISol
		nVlrSubTotal := MaFisRet( Nil, "NF_TOTAL" ) + aDesconto[03]
		nVlIpi	:= MaFisRet(,"NF_VALIPI")
		nVlSol	:= MaFisRet(,"NF_VALSOL")	
	EndIf
	
	Lj7T_DescP( 2, aDesconto[02] )
	Lj7T_SubTotal( 2, nVlrSubTotal )
	Lj7SetDescAnt( aDesconto[03] )

	If nOpc <> 2
		If cPaisLoc == "BRA"
			Lj7T_Total( 2, Lj7T_SubTotal(2) - Lj7T_DescV(2) + Lj7CalcFrete() )

			If lFtvdVer12
				/*	Recupera o Valor do SUFRAMA	*/
				If MaFisRet(,"NF_SUFRAMA")
					nDescSufr := MaFisRet(,"NF_DESCZF")
					If Len(aTotais) > 6
						LjVDT_SUFR(2, nDescSufr)
					EndIf
				EndIf				
			EndIf

		Else
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Realiza tratamento para localizacoes. Pois se o   ³
			//³MV_DESCSAI estiver como 2, o SubTotal ja esta com ³
			//³desconto.                                         ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If cMvDescSai == "1" .AND. cPaisLoc == "MEX"
				Lj7T_Total( 2, Lj7T_SubTotal(2) + Lj7CalcFrete() )
			ElseIf cMvDescSai == "1"
            	Lj7T_Total( 2, Lj7T_SubTotal(2) - Lj7T_DescV(2) + Lj7CalcFrete() )
			ElseIf cMvDescSai == "2"
				Lj7T_Total( 2, Lj7T_SubTotal(2) + Lj7CalcFrete() + Round( ( Lj7T_SubTotal(2) * (M->LQ_JUROS/100) ),2))
			EndIf
		EndIf
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Acerta a variavel de acrescimo                               ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If SL1->L1_JUROS > 0
	    If cPaisLoc $ "ARG|CHI|COL" .AND. nOpc == 2
		    aAcrescimo[1] := ( nVlrParcelas + SL1->L1_CREDITO - LJ7T_SubTotal(2) - Lj7CalcFrete() )   // Valor do acrescimo
	    Else
	    	aAcrescimo[1] := ( nVlrParcelas + Iif( LJxDAbISS(), MaFisRet(,'NF_VALISS'), 0 ) + SL1->L1_CREDITO - ;
			                   LJ7T_SubTotal(2) + aDesconto[3] - Lj7CalcFrete() )		  // Valor do acrescimo
		EndIf
	    aAcrescimo[2] := SL1->L1_JUROS														// Percentual do acrescimo
   	Endif

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Se for visualizacao ou finalizacao soma o acrescimo ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
    If nOpc == 2 .OR. nOpc == 4
	    If cPaisLoc == "BRA"		    
		    Lj7T_Total( 2, Lj7T_SubTotal(2) - Lj7T_DescV(2) + aAcrescimo[1] )

		    If nOpc == 2
		    	aAcrescimo[1] += nVlrAcrFin
		    EndIf

		    If lFtvdVer12
		    	/*	Recupera o Valor do SUFRAMA	*/
		    	If MaFisRet(,"NF_SUFRAMA")
					nDescSufr := (SL1->L1_VALMERC - MaFisRet(,"NF_TOTAL"))
					If Len(aTotais)>6
						LjVDT_SUFR(2, nDescSufr)
					EndIf
				EndIf
		    EndIf

		Else
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Realiza tratamento para localizacoes. Pois se o   ³
			//³MV_DESCSAI estiver como 2, o SubTotal ja esta com ³
			//³desconto.                                         ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If cMvDescSai == "1"
				Lj7T_Total( 2, Lj7T_SubTotal(2) - iIf(cPaisLoc$"MEX|ARG", 0, Lj7T_DescV(2)) + aAcrescimo[1] )
			ElseIf cMvDescSai == "2"
				Lj7T_Total( 2, Lj7T_SubTotal(2) + aAcrescimo[1] )
			EndIf
		EndIf

	EndIf

	If nOpc == 2 .AND. lECommerce .AND. lMvLjIPEn  .AND. ExistFunc("Lj7SetIPEC")
		Lj7SetIPEC(MaFisRet(,"NF_VALIPI"))
	EndIf
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Pega o codigo da loja local                                              ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If Empty(cLojaLocal)
		DbSelectArea("SLJ")
		DbSetOrder(3)	// Filial + RpcEmp + RpcFil
		If DbSeek(xFilial("SLJ")+SM0->M0_CODIGO+FWGETCODFILIAL)
			cLojaLocal := SLJ->LJ_CODIGO
		EndIf
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Carrega as variaveis ref. a moeda                            ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If cPaisLoc <> "BRA"
	   Lj7SetMoeda(SL1->L1_MOEDA,SL1->L1_TXMOEDA)
	   Lj7SetPicture()
    EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Ajusta a variavel na tela do Troco                           ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	Lj7AjustaTroco()

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Inicializa a linha no aCols  ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	n := 1
EndIf

If Len(aTmpCols)>0 
	LJAgrupaKit(aTmpCols,aTmpHeader)
EndIf 

aHeader 	:= aClone(aTmpHeader)
aCols   	:= aClone(aTmpCols)

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Restaura area anterior                                       ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
RestArea(aArea)

Return Nil


//-------------------------------------------------------------------
/*/{Protheus.doc} LJAgrupaKit
@description No momento do carregamento do do orçamento, preenche o array 
				aProdKit, objeto que controla o agrupamento dos Kits.
@author caio.okamoto
@since 13/09/2018
@version 12.1.17
/*/
//-------------------------------------------------------------------
Static Function LJAgrupaKit(aTmpCols, aTmpHeader)
Local nX			:= 0 //contador do laço que percorre o array aTmpCols
Local cChaveMEV 	:="" //valor da chave da tabela MEV
Local nPosicaoItem :=0 	 //posição do item no array aTmpCols  
Local cCodKIT		:="" //codigo do Kit do item, caso for <>"" significa que o item faz parte do KIT em questão
Local nPosLR_KIT    := Ascan(aTmpHeader,{|x| AllTrim(Upper(x[2])) == "LR_KIT"})                      // Posição do campo que indica se o item pertence a um kit
Local nPosProd 		:= Ascan(aTmpHeader,{|x| AllTrim(Upper(x[2])) == "LR_PRODUTO"})      // Posicao da codigo do produto
Local nPosItem 		:= Ascan(aTmpHeader,{|x| Alltrim(Upper(x[2])) == "LR_ITEM"})         // Posicao do Codigo do item


For	nX := 1 to Len(aTmpCols)

	If Alltrim(aTmpCols[nX][nPosLR_KIT]) <> ""
		
		cCodKIT := PadR(aTmpCols[nX][nPosLR_KIT],TamSX3("MEV_CODKIT")[1])
		nPosicaoItem := aTmpCols[nX][nPosItem]

		DbSelectArea("MEV")
		MEV->(DbSetOrder(1))  // MEV->MEV_FILIAL + MEV->MEV_CODKIT
		cChaveMEV := xFilial("MEV") + cCodKIT 
		
		If MEV->(DbSeek(cChaveMEV))
			
			While !MEV->(Eof()) .AND. (MEV->MEV_FILIAL + MEV->MEV_CODKIT == cChaveMEV)
			
				If MEV->MEV_PRODUT == aTmpCols[nX][nPosProd] .AND. MEV->MEV_CODKIT == cCodKIT  
					Lj7SetKit(nX,aTmpCols[nX][nPosItem],AllTrim(aTmpCols[nX][nPosProd]), cCodKIT, nPosicaoItem)
				EndIf
				
				MEV->(DbSkip())
				
				if !MEV->(Eof()) .AND. (MEV->MEV_FILIAL + MEV->MEV_CODKIT == cChaveMEV)
					nX++ // se o item do array aTmpCols faz parte de um KIT alimenta a aProdKIT e move para proxima posição 
				EndIf  

			End

		EndIf 
	
	EndIf 

Next nX

Return

//------------------------------------------------------------------------------------------
/*/{Protheus.doc} Lj7RetPos
Retorna posicao para criacao de objetos

@author    Vendas Cliente
@version   11.8
@since     29/06/2002
@return	Retorna posicao para criacao de objetos
@param		aExp1 - Array com a area total da tela
			aExp2 - Array da area de trabalho
			aExp3 - Array da toolbar a direita
			aExp4 - Array dos objetos
			aExp5 - Array dos objetos (contem a area do Panel de Pagamentos.
			aExp6 - Array dos objetos totais (dentro do Panel de totais)
/*/
//------------------------------------------------------------------------------------------
Static Function Lj7RetPos(	aSize1		, aPosObj1	, aPosObj2	, aPosObj3	,;
								aPosObj4	, aPosObj5	)
//Define a area de trabalho da tela
//Area T.Trab = Area da tela - (Area Enchoicebar+Area Toolbar)
//Obs: O aSize1 foi definido na funcao principal
Local aObjects1	:= {}		// Definicao da area dos objetos
Local aInfo1		:= {}		// Informacoes para a divisao da area

//Define a area da toolbar a direita
Local aSize2		:= {}
Local aObjects2	:= {}
Local aInfo2		:= {}

// Define a area dos objetos - Enchoice, Getdados e Panel
Local aSize3		:= {}
Local aObjects3	:= {}
Local aInfo3		:= {}

//Define a area do objeto - Panel para Pagamentos
Local aSize4		:= {}
Local aObjects4	:= {}
Local aInfo4		:= {}

//Define a area do objeto - Dentro do Panel de Totais
Local aObjects5	:= {}
Local aInfo5		:= {}

//Define outras variaveis
Local nCount1		:= 0				// Contador 1
Local nCount2		:= Len(aFuncoes)	// Contador 2
//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida

//Adiciona objetos para calculo da area
//Toolbar e Enchoicebar
aAdd( aObjects1, { 100, 100, .T., .T. } )
aAdd( aObjects1, { 010, 100, .F., .T. } )	// Reserva a toolbar lateral direita (X e sempre fixo)

aInfo1		:= { aSize1[ 1 ], aSize1[ 2 ], aSize1[ 3 ], aSize1[ 4 ], 2, 2 }
aPosObj1	:= MsObjSize( aInfo1, aObjects1, , .T. )

//Adiciona os botoes para calculo de area
For nCount1 := 1 To nCount2
	aAdd( aObjects2, { 28,  28, .F., .F., .T. } )
Next nCount1

//Define a area da toolbar a direita
//Foi adicionado +15 na altura da barra p/ simular um BMP maior
//isso possibilitara os botoes sairem na mesma altura que a Enchoice.
aSize2   := aPosObj1[2]
aInfo2   := { aSize2[ 2 ], aSize2[ 1 ]+15, aSize2[ 4 ], aSize2[ 3 ], 0, 0 }
aPosObj2 := MsObjSize( aInfo2, aObjects2, .F. , .F. )

//Adiciona objetos para calculo da area
//Enchoice, Getdados e Panel
If lFtvdVer12
	aAdd( aObjects3, { 010, 008, .T., .F. } )		// Botoes Superiores y sempre fixo
EndIf
aAdd( aObjects3, { 050, 025, .T., .T. } )			// Enchoice (Cabecalho)
aAdd( aObjects3, { 080, 050, .T., .T. } )			// GetDados (Itens)
aAdd( aObjects3, { 025, 015, .T., .F., .T. } )	// Panel 1 (Totais)
aAdd( aObjects3, { 025, 010, .T., .F., .T. } )	// Panel 2 (Mensagens)

aSize3		:= aPosObj1[1]
aInfo3		:= { aSize3[ 2 ], (aSize3[ 1 ] - iIf(!lFtvdVer12,20,30)), aSize3[ 4 ], aSize3[ 3 ], 2, 2 }
aPosObj3	:= MsObjSize( aInfo3, aObjects3, .T. , .F. )

//Adiciona objetos para calculo da area da Enchoice, Getdados e Panel
//E feito dessa forma para identificar a area que a GetDados ocupa. 
//Lembrando que a diferenca entre a GetDados e o Panel e que o 2o precisa 
//estar em pixel, dai a necessidade de repetir os objetos.
aAdd( aObjects4, { 050, 025, .T., .T. } )			// Enchoice	(Cabecalho)
aAdd( aObjects4, { 080, 050, .T., .T., .T. } )	// Panel 3	(Pagamentos)
aAdd( aObjects4, { 025, 015, .T., .F., .T. } )	// Panel 1	(Totais)
aAdd( aObjects4, { 025, 010, .T., .F., .T. } )	// Panel 2	(Mensagens)

aSize4		:= aPosObj1[1]
aInfo4		:= { aSize4[ 2 ], (aSize4[ 1 ]- iIf(!lFtvdVer12,20,30)), aSize4[ 4 ], aSize4[ 3 ], 2, 2 }
aPosObj4	:= MsObjSize( aInfo4, aObjects4, .T. , .F. )

//Adiciona objetos para calculo da area
//dos objetos dentro do Panel totais
//I  M  P  O  R  T  A  N  T  E
//Esses objetos estao 'pendurados' no aPosObj4[3]

aAdd( aObjects5, { 060, 030, .T., .T. } )	// Titulo do subtotal
aAdd( aObjects5, { 060, 030, .T., .T. } )	// Valor  do subtotal
aAdd( aObjects5, { 045, 030, .T., .T. } )	// Titulo do Desconto %
aAdd( aObjects5, { 045, 030, .T., .T. } )	// Valor  do Desconto %
aAdd( aObjects5, { 045, 030, .T., .T. } )	// Titulo do Desconto $
aAdd( aObjects5, { 045, 030, .T., .T. } )	// Valor  do Desconto $
aAdd( aObjects5, { 050, 030, .T., .T. } )	// Titulo Totalizador Volume
aAdd( aObjects5, { 050, 030, .T., .T. } )	// Quantidade Totalizador Volume
aAdd( aObjects5, { 070, 030, .T., .T. } )	// Titulo do Total da venda
aAdd( aObjects5, { 080, 030, .T., .T. } )	// Valor  do Total da venda

If lFtvdVer12
	aAdd( aObjects5, { 085, 030, .T., .T. } )	// Titulo do Suframa
	aAdd( aObjects5, { 085, 030, .T., .T. } )	// Valor do Suframa
EndIf

aInfo5 := { 0, 0, aPosObj4[3,3], aPosObj3[3,4], 2, 2 }
aPosObj5 := MsObjSize( aInfo5, aObjects5, .T., .T. )

Return .T.


/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³ Lj7PosRel ³ Autor ³ Vendas Cliente       ³ Data ³ 01/07/02 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Atribui a posicao relativa dos campos para uso no aCols    ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ Lj7PosRel( aExp1, aExp2, aExp3 )                           ³±±
±±³          ³ aExp1 - Array que contem QUAIS campos sao utilizados no 	  ³±±
±±³          ³         aCols.	                                          ³±±
±±³          ³ aExp2 - Array que contem QUAIS campos sao utilizados no    ³±±
±±³          ³         aCols.	                                          ³±±
±±³          ³ aExp3 - Array com os campos que serao utilizados no        ³±±
±±³          ³         aColsDet (aCols que contem os detalhes dos produ-  ³±±
±±³          ³         tos)                                               ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701 													  ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7PosRel( aCpoGDa, aCampos, aCpoGDaDet )
Local nCount1	:= 0						// Contador 1
Local nCount2	:= Len(aCpoGDa)				// Contador 2 - Contem quantidade de campos do aCols
Local nPos 		:= 0                        // Posicao de busca dentro do array

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Tratamento dos campos da aCols                               ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
For nCount1 := 1 To nCount2
	nPos := Ascan(aCampos,{|x| AllTrim(x) == AllTrim(aCpoGDa[nCount1])})
	aAdd( aPosCpo, { aCpoGDa[ nCount1 ], nPos } )
Next nCount1

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Tratamento dos campos da aColsDet                            ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
nCount1 := 0
nCount2 := Len(aCpoGDaDet)
For nCount1 := 1 to nCount2
	nPos := aScan( aHeaderDet, { |x| Alltrim(Upper(x[2])) == Alltrim(Upper(aCpoGDaDet[nCount1])) } )
	aAdd( aPosCpoDet, { aCpoGDaDet[ nCount1 ], nPos } )
Next nCount1

Return .T.


/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³ Lj7MPopUp ³ Autor ³ Vendas Cliente       ³ Data ³ 08/07/02 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Monta o menu PopUp										  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ Lj7MPopUp(nExp1, oExp2, aExp3)							  ³±±
±±³			 ³ nExp1 - Qual a opcao foi selecionada						  ³±±
±±³			 ³ oExp2 - Objeto que contem o panel de pagamentos			  ³±±
±±³			 ³ aExp3 - Objeto que contem a posicao que o panel de 		  ³±±
±±³			 ³ pagamentos devera ser montado.					 		  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701 													  ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7MPopUp( nOpcao, oPanVA3, aPosObj4 )
Local oMenu
Local oMenuItem	:= {}
Local nCount1	:= 0
Local nCount2	:= Len(aFuncoes)
//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida

MENU oMenu POPUP

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Esta habilitado para aparecer no menu ?						 ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	For nCount1 := 1 To nCount2
		If Lj7F_Grup(nCount1) == nOpcao
			aAdd( oMenuItem, MenuAddItem( Lj7F_Titu(nCount1),,, Lj7F_Menu(nCount1),,,, oMenu, Lj7F_Func(nCount1),,,,,{|| .T.}) )
		EndIf
	Next nCount1

ENDMENU

If !lFtvdVer12
	ACTIVATE POPUP oMenu AT 10+nOpcao+(60*(nOpcao-1)),oDlgVA:nTop+32
ElseIf lFtvdVer12
	ACTIVATE POPUP oMenu AT 10+oDlgVA:nLeft+(100*nOpcao),oDlgVA:nTop+140
EndIf

Return .T.

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³ Lj7Sair	 ³ Autor ³ Vendas Cliente       ³ Data ³ 08/07/02 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Sai da venda										 		  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ ExpL1 := Lj7Sair( ExpN1, ExpN2, ExpA3 )                    ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ ExpN1 - nOpc. Rotina executada na MBrowse                  ³±±
±±³          ³ ExpN2 - Controle do semaforo (SX8)                         ³±±
±±³          ³ ExpA3 - Array com os dados do documento de entrada gerado  ³±±
±±³          ³ pela devolucao de mercadorias						      ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Retorno   ³ ExpL1 - Logico. Se permite ou nao sair da venda            ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701 													  ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7Sair( nOpc		, nSaveSx8	, aDocDev ,lTefPendCS,;
				  aTefBKPCS	, lErroNFCe	, lErroNFe )
Local lRet			:= .T.
Local aReservas		:= {}
Local nX			:= 0
Local nPosProd		:= aPosCpo[Ascan(aPosCpo,{|x| Alltrim(Upper(x[1])) == "LR_PRODUTO"})][2] 		// Posicao da codigo do produto
Local nPosDtReserva	:= Ascan(aPosCpoDet,{|x| Alltrim(Upper(x[1])) == "LR_RESERVA"})				// Posicao do codigo da reserva
Local nPosDtLojaRes	:= Ascan(aPosCpoDet,{|x| Alltrim(Upper(x[1])) == "LR_LOJARES"})				// Posicao do codigo da reserva
Local nPosDtLocal  	:= Ascan(aPosCpoDet,{|x| Alltrim(Upper(x[1])) == "LR_LOCAL"})					// Posicao do local (armazem)
Local nPosItem		:= aPosCpo[Ascan(aPosCpo,{|x| Alltrim(Upper(x[1])) == "LR_ITEM"})][2]		    // Posicao do Codigo do item
Local	nPosSublote	:= aScan(aHeaderDet,{|x| Alltrim(Upper(x[2]))=="LR_NLOTE"})					// Posicao do subLote
Local	nPosLote		:= aScan(aHeaderDet,{|x| Alltrim(Upper(x[2]))=="LR_LOTECTL"})				// Posicao do Lote
Local	nPosEndereco	:= aScan(aHeaderDet,{|x| Alltrim(Upper(x[2]))=="LR_LOCALIZ"})				// Posicao do Endereco
Local	nPosNumSerie	:= aScan(aHeaderDet,{|x| Alltrim(Upper(x[2]))=="LR_NSERIE"})					// Posicao do num de serie
Local nPosMesRec		:= Ascan(aPosCpoDet,{|x| Alltrim(Upper(x[1])) == "LR_MESREC"})				// Posicao do numero do recno da tabela MES
Local aMesRec			:= {}																					// Guarda numeros de contingencias geradas

Local lCentPDV		:= IIf( FindFunction("LjGetCPDV"), LjGetCPDV()[1] , .F. ) // Central de PDV
Local aLote			:= {}									// Guarda lote
Local cMsg 			:= "" 																	   		// Mensagem que sera mostrada na tela de confirmacao de saida da rotina.
Local aNumContra    := {}                      														// Array com os contratos que devem ser verificados se serao cancelados
Local cRetorno		:= Space(10)																	// Variavel que controla o retorno
Local aRet			:= {.F.,'',''}																	// Array contendo informações do retorno
Local nRet          := 0																			// variavel numerica de retorno
Local lVAssConc		:= LjVassConc()										//Indica se o cliente utiliza a Vda Assistida Concomitante
Local lConfSaida    := .T.                      													// Controla se deve pergunta se deseja sair da venda
Local lGravacao     := ("LJ7GRAVACAO" $ Upper(ProcName(3)) .Or. "LJSALVAVDA" $ Upper(ProcName(3)))//Controla se foi chamado da gravacao(orcamento ou venda)
Local lLj7033       := ExistBlock( "LJ7033" )                 										//Controla se existe o ponto de entrada LJ7033
Local lUsafd      	:= SuperGetMV("MV_LJUSAFD",,.F.) 												// Utiliza Fidelizacao de cliente ??
Local lLog4         := Subs(LJGetProfile("LOGERRO"),4,1) == "S" 									// Log de Recuperacao, grava as parcelas
Local lLj7047       := FindFunction ("U_LJ7047")                                                 	// Verifica se Existe o Ponto de Entrada
Local xRet                                                                                          // Variavel de retormo do ponto de entrada
Local lValReserv    := .F.                                                                          // Valida a Delecao da reserva quando for Tempalte de Otica
Local nCount        := 0                                                                            // Contador do For
Local lVendaPerdida := Lj7VldVp() 																	// Habilita funcionalidade de vendas perdidas
Local lTdItemDel	:= .F. 																			// Verifica se todos os Itens do aCols estao deletados
Local lTemRecCel	:= .F. 																			// Variavel que controla se existe "Recarga de Celular" na venda
Local lFTVD7033     := ExistBlock( "FTVD7033" )
Local lFTVD7047     := FindFunction ("U_FTVD7047")
Local nPL2LegCod	:= 0																			// Posicao do Codigo do Abastecimento(LEG) quando template de Posto de Combustivel
Local aAreaSL2		:= SL2->(GetArea())            													// Guarda Area SL2
Local lItemResConf	:= .F.																			// Identifica se já havia reserva gravada na tabela SL2
Local lTemRecCP		:= .F. 																			// Variavel que controla se existe "Recarga de Cartao Presente" (Gift Card) na venda
Local cLJRESER 		:= SuperGetMV("MV_LJRESER ",,"1")	 											//Controla como será realizada a reserva de produtos da venda. 1=Ao pressionar o botão F11; 2=Na gravação do orçamento; 3=Na gravação da venda.
Local cMVLJTEFPD	:= "" 																			//Determina se as transacoes TEF pendentes serao "1=Confirmadas", "2=Canceladas" ou "3=Permanecem Pendentes"
//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida

DEFAULT lTefPendCS := .F.
DEFAULT aTefBKPCS  := {}
DEFAULT lErroNFCe  := .F.
DEFAULT lErroNFe   := .F.

LjGrvLog("","Inicio da execucao da funcao Lj7Sair",lRet)

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Inclusao do  ponto de entrada LJ7047 para permitir ou nao a saida da tela³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lLj7047 .AND. !lFtvdVer12
	LjGrvLog("","Executa o PE LJ7047 - Parametro 1",lGravacao)
	LjGrvLog("","Executa o PE LJ7047 - Parametro 2",aDocDev)
	LjGrvLog("","Executa o PE LJ7047 - Parametro 3",nOpc)
   xRet  := U_LJ7047(lGravacao, aDocDev, nOpc)
   If ValType(xRet) == "L"
      lRet  := xRet
   EndIf
   LjGrvLog("","Retorno do PE LJ7047",xRet)
EndIf

If lFTVD7047 .AND. lFtvdVer12
   xRet  := U_FTVD7047(lGravacao, aDocDev, nOpc)
   If ValType(xRet) == "L"
      lRet  := xRet
   EndIf
EndIf

LjGrvLog("","Fechando a tela do Venda Assistida",lRet)

If lRet
	If !lGravacao

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Nao checa as reservas se for Visualizacao                    ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If nOpc <> 2
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Checa se existe reserva. Nao permitir abandonar a rotina     ³
			//³ e deixar rotinas pendentes.                                  ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If !Empty(aColsDet)
				For nX := 1 to Len(aCols)
					If !aCols[nX][Len(aCols[nX])] .AND. Len(aColsDet) >= nX .AND. !Empty(aColsDet[nX][nPosDtReserva])
						// Opcao igual a "Finalizacao da Venda"
						// Se na finalizacao o parametro tiver como 3 significa que deve excluir a reserva na saida da venda, pois acabou de reservar
						If nOpc == 4 .AND. cLJRESER <> "3"
							// Verifica se a reserva ja foi efetuada (Gravada na tabela SL2)
							// Se nao a mesma sera adiociona no array aReservas para ser cancelada
							DbSelectArea("SL2")
							DbSetOrder(5) // SL2->L2_FILIAL + SL2->L2_RESERVA + SL2->L2_LOJARES + SL2->L2_PRODUTO + SL2->L2_ITEM
					   	   	If !SL2->(DbSeek(xFilial("SL2") + aColsDet[nX][nPosDtReserva] + aColsDet[nX][nPosDtLojaRes] + aCols[nX][nPosProd] + aCols[nX][nPosItem]))
								aAdd(aReservas, {	aColsDet[nX][nPosDtReserva],;		// Codigo da reserva
													aColsDet[nX][nPosDtLojaRes],;		// Codigo da loja
													aCols[nX][nPosProd],;				// Codigo do produto
													aColsDet[nX][nPosDtLocal],;			// Local (armazem) da reserva
													NIL,;
													aCols[nX][nPosItem]})				// Item

								//Central de PDV
								If lCentPDV
									aLote := {aColsDet[nX][nPosSublote] 	,;	// SubLote
											  	aColsDet[nX][nPosLote]    	,;	// Lote
											  	aColsDet[nX][nPosEndereco]	,;	// Endereco
											  	aColsDet[nX][nPosNumSerie]	}	// Numero de serie

									aAdd( aReservas[nX], aLote  )

									If !Empty(aColsDet[nX][nPosMesRec]) .AND. aColsDet[nX][nPosMesRec] > 0
										aAdd( aMesRec, aColsDet[nX][nPosMesRec]  )
									EndIf
								EndIf
							Else
								// Se encontrar reserva ja gravada, passa lItemResConf
								// para que nao seja apagado numero da reserva nas tabela SL1 e SL2
								// pois na funcao eh verificado pelo campo SL1->L1_NUM
								lItemResConf := .T.
							EndIf
						Else
							aAdd(aReservas, {	aColsDet[nX][nPosDtReserva],;		// Codigo da reserva
												aColsDet[nX][nPosDtLojaRes],;		// Codigo da loja
												aCols[nX][nPosProd],;				// Codigo do produto
												aColsDet[nX][nPosDtLocal],;			// Local (armazem) da reserva
												NIL,;
												aCols[n][nPosItem]})				// Item

							//Central de PDV
							If lCentPDV
								aLote := {aColsDet[nX][nPosSublote] 	,;	// SubLote
										  	aColsDet[nX][nPosLote]    	,;	// Lote
										  	aColsDet[nX][nPosEndereco]	,;	// Endereco
										  	aColsDet[nX][nPosNumSerie]	}	// Numero de serie

								aAdd( aReservas[nX], aLote  )

								If !Empty(aColsDet[nX][nPosMesRec]) .AND. aColsDet[nX][nPosMesRec] > 0
									aAdd( aMesRec, aColsDet[nX][nPosMesRec]  )
								EndIf

							EndIf
						Endif
					EndIf
				Next nX
			EndIf

			RestArea(aAreaSL2)

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Verifica se eh necessario cancelar as reservas mas soh se    ³
			//³ for opcao de orcamento. Nao deve fazer a validacao se for    ³
			//³ Finalizacao da venda.                                        ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If HasTemplate("OTC")
			   DbSelectArea("SL1")
			   DbSetOrder(1)
			   	   If DbSeek(xFilial("SL1") + M->LQ_NUM )
				      lValReserv := .T.
			      	  If ExistTemplate("LJ7002") .AND. !lFtvdVer12
		              	 ExecTemplate( "LJ7002", .F., .F., {1, Nil, 1} )
	                  EndIf
                  	  If ExistTemplate("FTVD7002") .AND. lFtvdVer12
	              	 	ExecTemplate( "FTVD7002", .F., .F., {1} )
                      EndIf
			       EndIf
			   If nOpc == 3.AND. !lValReserv
			   		DbSelectArea("LF4")
			   		DbSetOrder(2)
			   		If DbSeek(xFilial("LF4") + M->LQ_NUM)
			      		RecLock( "LF4", .F. )
		          		REPLACE LF4->LF4_NUMORC WITH ""
		          		MsUnlock()
			   		EndIf
			   EndIf
			EndIf
		EndIf

		// nOpc = 3 - Opcao "Atendimento"
		// nOpc = 4 - Opcao "Finaliza Venda"
		If !Empty(aReservas) .AND. (nOpc == 3 .OR. nOpc == 4) .AND. !lValReserv
			If lAutoExec .Or. (!lAutoExec .And. MsgYesNo(STR0013))		//"As reservas que foram efetuadas serão canceladas. Deseja sair da venda ?"
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³ Faz o cancelamento das reservas                              ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				If !lAutoExec
					LjGrvLog(SL1->L1_NUM,"A reserva sera cancelada")
				EndIf

				//Se for central de Pdv executa cancelamento local e via componente de comunicacao
				If lCentPDV

					If Len(aMesRec) > 0

						// Cancela contingencias locais que ainda nao subiram para o BackOffice
						Lj7CancContg(aMesRec)

					EndIf

					// Executa cancelamento no BackOficce
					lContinua := STBRemoteExecute("Lj7CancRes", { aReservas , Nil , lCentPDV } , NIL, .T. , @aRet , "01" , SL2->L2_FILIAL+SL2->L2_NUM+SL2->L2_ITEM+SL2->L2_PRODUTO)

				Else
					Lj7CancRes( aReservas)
				EndIf

				// Se nao foi encontrada nenhuma reserva feita anteriormente
				// Chama funcao Lj7AtuResOrc para limpeza dos dados da reserva
				If !lItemResConf
					Lj7AtuResOrc(M->LQ_NUM, .T.)
				Endif

				lRet := .T.
			Else
				If !lAutoExec
					LjGrvLog(SL1->L1_NUM,"Selecionou para NAO cancelar a reserva")
				EndIf
				lRet := .F.
			EndIf
			lConfSaida  := .F.
		EndIf
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Se realizou uma troca, verifica se deseja estornar a operacao³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If lRet .AND. Len(aDocDev) > 0 .AND. nOpc <> 2 .AND. aDocDev[5] == 1
		   //"ATENÇÃO!! Confirma a saida da rotina e o cancelamento da operacao de troca?"
		   If lAutoExec .Or. (!lAutoExec .And. MsgYesNo(STR0104))
		      Lj720EstTroc(aDocDev)
		      lRet  := .T.
		   Else
		      lRet  := .F.
		      LjGrvLog("","Confirma a saida da rotina e o cancelamento da operacao de troca?",lRet)
		   EndIf
		   lConfSaida  := .F.
		EndIf
		If nOpc == 2
		   cMsg := STR0093		// 'Deseja sair da visualizacäo ?'
		Else
		   cMsg := STR0014 	// 'Deseja sair da venda ?'
		EndIf

		If lRet .And. nOpc <> 2
			//Verifica se na venda tem "Recarga de Celular" ou "Recarga de Cartao Presente" (Gift Card)
			If Lj7RCStatus() //Verifica se tem "Recarga de Celular"
				cMsg := STR0286 //"Existe Recarga de Celular nesta venda, deseja efetuar o cancelamento e abandonar a venda?"
				lTemRecCel := .T.
			ElseIf FindFunction("Lj7CP_OK") .And. Lj7CP_OK() .And. Lj7CPGetSt()=="S" //Verifica se tem "Recarga de Cartao Presente" (Gift Card)
				cMsg := STR0320 //"Existe Recarga de Cartao Presente nesta venda, deseja efetuar o cancelamento e abandonar a venda?"
				lTemRecCP := .T.
			EndIf
		EndIf

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Faz o cancelamento do Cupom quando for concomitante qdo sair ³
		//³ da venda. Nao faz essa verificacao qdo eh visualizacao       ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If lRet .AND. nOpc <> 2 .AND. lVAssConc .AND. !lAutoExec .And. !lIsPafNfce
		   //ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		   //³ Verifica se ha um cupom em aberto. Caso afirmativo, faz o    ³
		   //³ cancelamento antes da abertura de outro                      ³
		   //³ .T. pergunta antes de cancelar o cupom                       ³
		   //ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		   nRet := IFStatus( nHdlECF, '5', @cRetorno )
		   If nRet == 7
		      //"Existe um Cupom Fiscal em aberto, deseja efetuar o cancelamento e abandonar a venda ?"
		      cMsg := STR0103
			  lRet := IIF(lAutoExec,.T.,MsgYesNo( cMsg, STR0015 ))		//###'Atenção'
			  LjGrvLog("","Confirma a saida?",lRet)
			  If lRet
				  If LjProfile(8)
				     nRet := IFCancCup( nHdlECF )

					 //ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					 //³Cancela importacao de orçamento caso seja PDV³
					 //ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					 If lMvLjPdvPa
 						/*Quando PAF-ECF e Template de Posto, remove sinalização de Abastecimento em Uso*/
						If HasTemplate("PCL") .AND. ExistTemplate("TpPclAtuLeg")
							nPL2LegCod	:= Ascan(aPosCpo,{|x| Alltrim(Upper(x[1])) == "LR_LEGCOD"})	// Posicao do Codigo do Abastecimento

							If nPL2LegCod > 0
								For nX:=1 to Len(aCols)
									If !Empty(aCols[nX][nPL2LegCod])
										FR271CMyCall("T_TpPclAtuLeg",{"LEG"},aCols[nX][nPL2LegCod],"P")
										T_TpPclIBomb() //Chama rotina apenas para limpar mensagem armazenada
									EndIf
								Next nX
							EndIf
					 	EndIf
					 	
					 	LJ7CancImp()
					 EndIF
					 If Lj7VerCmd( nRet )
						//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
						//³dá um tempo para a impressora fazer a impressao do cancelamento³
						//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					    Inkey(8)
						lRet:=.T.
					 Else
					    lRet:=.F.
					    LjGrvLog("","Saida setada para .F. (1)",lRet)
					 EndIf
				  Else
				     lRet:=.F.
				     LjGrvLog("","Saida setada para .F. (2)",lRet)
				  EndIf
			  EndIf
		   ElseIf lConfSaida
		      lRet := IIF(lAutoExec,.T.,MsgYesNo( cMsg, STR0015 ))	   //###'Atenção'
		      LjGrvLog("","(1) Saida setada para: ",lRet)
		   EndIf
		ElseIf lConfSaida .AND. lRet
		   lRet := IIF(lAutoExec,.T.,MsgYesNo( cMsg, STR0015 ))	//###'Atenção'
		   LjGrvLog("","(2) Saida setada para: ",lRet)
		EndIf
	    If lRet
	    	LJ7DadosVL({1}) //Limpa dados PBM Funciona Card
			If lTemRecCel
				//Cancela a transacao TEF referente a "Recarga de Celular"
				Lj7RCStatus(.F.) //Atualiza o status para "Recarga NAO efetuada"
				oTef:FinalTrn(0) //Envia o desfazimento da transacao TEF
			EndIf

			If lTemRecCP
				//Cancela a transacao TEF referente a "Recarga de Cartao Presente" (Gift Card)
				Lj7CPSetSt(0) //Atualiza o status para "Recarga NAO efetuada"
				oTef:FinalTrn(0) //Envia o desfazimento da transacao TEF
			EndIf

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Zera a variavel statica lAlterOrc ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
            lAlterOrc := .F.

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Zera a variavel statica cCondSE4  ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		    LjZeracCondSE4()
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Apaga arquivo de recuperacao quando estiver configurado³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	        If lLog4
		    	LjDeLogR( M->LQ_NUM )
		    EndIf
		    //ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Libera o Registro do SE1 do LockByName			             ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If lRecebe .AND. Len(aTitulo) > 0
				For nX := 1 To Len(aTitulo)
					If ValType(aTitulo[nX]) == "A" .AND. Len(aTitulo[nX]) > 20
						UnLockByName(aTitulo[nX][21],.T.,.F.,.T. )
					EndIf
				Next nX
			EndIf
			If CrdxInt()
		      //ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		      //³Cancela o contrato caso nao seja associado ao orcamento           ³
		      //ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		      aNumContra  := AClone(Lj7GetContra())
		      If Len(aNumContra) > 0
	   	  		  Conout("1.LOJA701C - Lj7Sair - " +;
	   	  		  			" Orcamento: " 	+ If( Empty(M->LQ_NUM), "", M->LQ_NUM ) +;
		               		" Contrato: " 	+ If( Empty(aNumContra[1][1]), "", aNumContra[1][1]) +;
		      		  		" Chama a funcao CrdAtuPend " )

		         CrdAtuPend( "SL1"   ,10    ,aNumContra,.F.    ,;
		                      .T.    )
		      Else
		      	 Conout("1.LOJA701C - Lj7Sair - " +;
		      	 		" Orcamento: " 	+ If( Empty(M->LQ_NUM), "", M->LQ_NUM ) +;
		      	   		" Validacao: Len(aNumContra) = 0, nao chama a funcao CrdAtuPend " )
		      EndIf
		      //ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		      //³Restaura o backup dos arqs. MA7, MAH e MAL se nao confirmar a venda.    ³
		      //³Chamado apenas na finalizacao da venda, pois jah deve ter um orcamento  ³
		      //³associado a um contrato 											     ³
		      //ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		      If nOpc == 4
		      	 Conout("2.LOJA701C - Lj7Sair - " +;
		      	 		" Orcamento: " 	+ If( Empty(M->LQ_NUM), "", M->LQ_NUM ) +;
		               	" Contrato: " 	+;
		               	If (Len(aNumContra) > 0, If( Empty(aNumContra[1][1]), "", aNumContra[1][1]),"") +;
		      		   	" Chama a funcao Lj7RestInfCRD " )
		         Lj7RestInfCRD()
		      EndIf
		      //ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			  //³Inicializa as variaveis de contrato 								   ³
			  //ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	          Lj7SetCRDClie(.T.)          //Inicializa o array aCrdCliente e cContrato - Integracao SIGACRD

	          If lUsaFd
	    	      Lj7AtuPremio(.T.)	      //Inicializa as variaveis de Resgate de Premio
	          EndIf

	       Else
		   	  Conout("3.LOJA701 - Lj7PrepOrc - " +;
		   	  		" Orcamento: " + If( Empty(M->LQ_NUM), "", M->LQ_NUM ) +;
		   	  		"  Sem Integracao com o CRD")
	       EndIf
	    EndIf
	EndIf
EndIf

LjGrvLog("",If(lRet,"Vai","Nao vai") +" executar o PE LJ7033",)

If lRet
	While (GetSx8Len() > nSaveSX8)
		RollBackSx8()
	End
	MsUnlockAll()

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Na finalizacao de venda com reserva de um orcamento previamente gerado, quando o SL1 esta posicionado no registro filho ³
	//³posiciono-o no registro PAI para o correto fechamento da funcao Lj7XSL1.                                                |
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If nOpc == 4
		If SL1->L1_NUM <> M->LQ_NUM
			SL1->( DbSetOrder(1) )
			SL1->( DbSeek(xFilial("SL1")+M->LQ_NUM),.T.)
		EndIf
	EndIf
	Lj7XSL1('D')

	If lLj7033 .AND. !lFtvdVer12
		LjGrvLog("","Inicio da Execucao do PE LJ7033",)
	    ExecBlock("LJ7033", .F., .F., {lGravacao, nOpc})
	    LjGrvLog("","Fim da Execucao do PE LJ7033",)
	EndIf

	If lFTVD7033 .AND. lFtvdVer12
	    ExecBlock("FTVD7033", .F., .F., {lGravacao, nOpc})
	EndIf

	If FindFunction("Lj7FinalNF") .AND. nOpc <> 2
		Lj7FinalNF()
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Se tiver alguma operacao TEF pendente, verifica a acao a ser tomada. ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If lTefPendCS .AND. Type("oTEF") == "O"
		If FindFunction("LjTEFPend")
			cMVLJTEFPD := LjTEFPend(2)
		EndIf
		If cMVLJTEFPD == "1" //1=Confirma a transacao TEF Pendente
			MsgAlert("A transação TEF pendente desta venda será CONFIRMADA!", STR0015 ) //###"Atenção"
			LjGrvLog("","Mensagem exibida para o usuário: 'A transação TEF pendente desta venda será CONFIRMADA!'")
			oTEF:FinalTrn(1)  //CONFIRMA a transacao TEF Pendente
		ElseIf Empty(cMVLJTEFPD) .Or. cMVLJTEFPD == "2" //2=Cancela a transacao TEF Pendente
			MsgAlert("A transação TEF pendente desta venda será CANCELADA! Comunique o departamento de TI sobre esta ocorrência.", STR0015 ) //###"Atenção"
			LjGrvLog("","Mensagem exibida para o usuário: 'A transação TEF pendente desta venda será CANCELADA! Comunique o departamento de TI sobre esta ocorrência.'")
			oTEF:FinalTrn(0)  //CANCELA a transacao TEF Pendente (Envia o desfazimento da transacao TEF)
		ElseIf cMVLJTEFPD == "3" //3=Deixa pendente a transacao TEF
			//Neste caso, a Transacao TEF ficara pendente para ser confirmada ou cancelada manualmente pelo Software da SiTEF.
			MsgAlert("A transação TEF pendente desta venda permanecerá PENDENTE! Comunique o departamento de TI sobre esta ocorrência.", STR0015 ) //###"Atenção"
			LjGrvLog("","Mensagem exibida para o usuário: 'A transação TEF pendente desta venda permanecerá PENDENTE! Comunique o departamento de TI sobre esta ocorrência.'")
		EndIf
		lTefPendCS := .F.
		aTefBKPCS  := {}
	EndIf

	If FindFunction("LjLimpStat") // Limpa a varivel staticas no LOJXFUNB
		LjLimpStat()
	EndIf

EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Grava movimento de venda perdida durante a saida da venda, se todos os itens estiverem deletados ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If !lMVLJPDVPA .AND. lVendaPerdida .AND. FindFunction("LA701GetVp")
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Verifica todos SE TODOS os itens estao deletados³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
 	For nX := 1 To Len(aCols)
  		If  aTail(aCols[nX])
    		lTdItemDel := .T.
    	Else
    		lTdItemDel := .F.
    		Exit
    	EndIf
  	Next nX
  	If lTdItemDel
		oMoviVp 	:= LA701GetVp() //OBTER OBJETO DE MOVIMENTO DE VENDA PERDIDA, ATIVO NO LOJA701
		If oMoviVp	!= NIL
			LA701GrvVp (oMoviVp) //Grava VP sem num orcamento
		EndIf
	EndIf
EndIf
If ExistFunc("Lj7FinalNF") .AND. nOpc == 2
	Lj7FinalNF()
EndIf
LjGrvLog("","Fim da execucao da funcao Lj7Sair",lRet)
Return (lRet)


/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³ LjHeader  ³ Autor ³ Vendas Cliente       ³ Data ³ 22/06/02 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Carrega aCols (vazio para inclusao de orcamentos)          ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ Lj7Header(cExp1, aExp2, aExp3)                     		  ³±±
±±³          ³ cExp1 - Alias que sera carregado							  ³±±
±±³          ³ aExp2 - Array com os campos que devem ser carregados 	  ³±±
±±³          ³ aExp3 - Array que contera os itens						  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701 													  ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function LjHeader(cAlias, aCpoGDa, aTmpCols, lSugeAut)
Local nCount1	:= 0								// Contador 1
Local nCount2	:= 0								// Contador 2
Local nUsado	:= 0								// Contador de campo usado
Local aArea 	:= GetArea()						// Armazena area atual (alias, order e recno)
Local cSeek		:=""								// Variável que ira guardar o nome do campo, sera .F. quando sugestao automatica
//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida
Default lSugeAut := .F.                             // Variavel logica de Sugestao Vendas
DbSelectArea("SX3")
DbSetOrder(2)
nCount2 := Len(aCpoGDa)
For nCount1 := 1 To nCount2
	cSeek := Iif(lSugeAut,aCpoGDa[nCount1][2], aCpoGDa[nCount1])
	If DbSeek(cSeek)
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Critica se foi solicitado um campo que nao pertence ao Alias ³
		//³ da Getdados em questao										 ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If SX3->X3_ARQUIVO <> cAlias
			Loop
		EndIf

		nUsado++

		If X3_TIPO == "C"
			aTmpCols[1][nUsado] := Space(X3_TAMANHO)

		ElseIf X3_TIPO == "M"
			aTmpCols[1][nUsado] := ""

		ElseIf X3_TIPO == "L"
			aTmpCols[1][nUsado] := .F.

		Else
			aTmpCols[1][nUsado] := CriaVar( AllTrim(X3_CAMPO), .T. )

		EndIf

		If AllTrim(X3_CAMPO) == "LR_ITEM"
			aTmpCols[1][nUsado] := StrZero(1,TamSx3("LR_ITEM")[1])
		EndIf
	EndIf
	DbSkip()
Next nCount1
aTmpCols[1][nUsado+1] := .F.

RestArea(aArea)							// Restaura area anterior

Return(.T.)

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³ LjFontes	 ³ Autor ³ Vendas Cliente       ³ Data ³ 01/07/02 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Carrega no array PRIVATE aFontes os fontes que serao usados³±±
±±³			 ³ na exibicao das telas.									  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ LjFontes()					                         	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701 													  ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function LjFontes()

Local oFonte1
Local oFonte2
Local oFonte3

DEFINE FONT oFonte1 NAME "Arial" BOLD
DEFINE FONT oFonte2 NAME "Arial" SIZE 08,17 BOLD
DEFINE FONT oFonte3 NAME "Courier New"

aAdd(aFontes, oFonte1)
aAdd(aFontes, oFonte2)
aAdd(aFontes, oFonte3)

Return .T.

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7LinOk  ºAutor  ³ Vendas Cliente     º Data ³  27/07/02   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Valida a linha do Produto (MsGetDados Principal)           º±±
±±º          ³                                                            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ LOJA701                                                    º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7LinOk()

Local lRet 			:= .T. 						                     	 // Retorno da Funcao
Local nX 			:= 0                                                 // Controle de loop
Local lLJ7030T	    := ExistTemplate("LJ7030")
Local lLJ7030		:= ExistBlock("LJ7030")
Local lFTVD7030T	:= ExistTemplate("FTVD7030")
Local lFTVD7030		:= ExistBlock("FTVD7030")
Local nLJ7030		:= 0
Local cMensagem		:= ""
Local nPosMostruario:= AScan(aHeader,{|x| AllTrim(x[2]) == "LR_VDMOST" }) 	// Tipo, mostruario ou saldao
Local nPosObsMostrua:= AScan(aHeader,{|x| AllTrim(x[2]) == "LR_VDOBS" }) 	// Observacao, mostruario ou saldao
Local nPosProd		:= aPosCpo[Ascan(aPosCpo,{|x| Alltrim(Upper(x[1])) == "LR_PRODUTO"})][2] 		// Posicao da codigo do produto
//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Chamada do Ponto de Entrada para uso de Template               ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lLJ7030T .AND. !lFtvdVer12
	lRet := ExecTemplate( "LJ7030", .F., .F., { 1 } )
	If ValType(lRet) <> "L"
		lRet := .T.
	EndIf
EndIf

If lFTVD7030T .AND. lFtvdVer12
	lRet := ExecTemplate( "FTVD7030", .F., .F., { 1 } )
	If ValType(lRet) <> "L"
		lRet := .T.
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Chama o ponto de entrada na LinOk                              ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lLJ7030 .AND. !lFtvdVer12
	lRet := Execblock( "LJ7030", .F., .F., { 1 ,nLJ7030 } )
	If ValType(lRet) <> "L"
		lRet := .T.
	EndIf
EndIf

If lFTVD7030 .AND. lFtvdVer12
	lRet := Execblock( "FTVD7030", .F., .F., { 1 ,nLJ7030 } )
	If ValType(lRet) <> "L"
		lRet := .T.
	EndIf
EndIf

If lRet
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Checa os campos obrigatorios da Getdados                       ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If !aCols[n][Len(aCols[n])]
		For nX := 1 to Len( aCols[n] ) - 1
		    If X3Obrigat( Alltrim(aHeader[nX][2]) ) .AND. Empty( aCols[n][nX] )
		    	Help( " ", 1, "Help",, STR0123 + Alltrim(aHeader[nX][1]) + "' " + STR0280, 1, 0 ) // "O campo '" ; "deve ser preenchido."
		    	LjGrvLog("Lj7LinOk",STR0123 + Alltrim(aHeader[nX][1]) + "' " + STR0280)
		    	lRet := .F.
		    	Exit
			EndIf
		Next nX
	EndIf
EndIf

If lRet
	If aCols[n][Len(aCols[n])] == .F.
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Faz o ajuste do array de Detalhe dos produtos e chama as     ³
		//³ funcoes fiscais para calcular os impostos                    ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		LJ7Detalhe(.F.)
	EndIf	
EndIf

If lRet .AND. HasTemplate("PCL")
	lRet := T_TPLPCLVL()
EndIf

If lRet .AND. FindFunction("Lj7HasDtEM") .AND.  Lj7HasDtEM()
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Valida a data de entrega e montagem.³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	lRet := If( !Lj7ValEntr(,@cMensagem), .F., lRet )
	lRet := If( !Lj7ValMont(,@cMensagem), .F., lRet )

	If !lRet
		If lAutoExec
			Conout( cMensagem )
			Help( " ", 1, "Help",, cMensagem, 1, 0 )
			LjGrvLog("Lj7LinOk",STR0123 + Alltrim(aHeader[nX][1]) + "' " + STR0280)
		Else
			Alert( cMensagem )
		Endif
	EndIf
EndIf

//Validacao de produtos Mostruarios/Saldao
If lRet .And. nPosMostruario > 0 .And. nPosObsMostrua > 0 .And. !aCols[n][Len(aCols[n])] .And. aCols[n,nPosMostruario] <> "N" .And. !Empty(aCols[n,nPosMostruario]) .And. Empty(aCols[n,nPosObsMostrua])
	If !lAutoExec
		Aviso(STR0196,STR0197,{"Ok"},2)	 //"Produto Mostruário/Saldão"#"Ao informar uma venda de um item de mostruário ou saldão, é obrigatório informar a observação do item."
	Else
		Conout(STR0196 + " - " + STR0197)	 //"Produto Mostruário/Saldão"#"Ao informar uma venda de um item de mostruário ou saldão, é obrigatório informar a observação do item."
		Help( " ", 1, "Help",, STR0196 + " - " + STR0197, 1, 0 )
		LjGrvLog("Lj7LinOk", STR0196 + " - " + STR0197)
	Endif
	lRet := .F.
EndIf

Eval(bRefresh)

Return lRet

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7TudOk  ºAutor  ³ Vendas Cliente     º Data ³  01/10/2002 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Valida todos os itens cadastrados. (MsGetDados Principal)  º±±
±±º          ³                                                            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ExpN1 - Incica se a funcao foi chamada via                  º±±
±±º          ³      1 - Salvar como orcamento                             º±±
±±º          ³      2 - Salvar como venda                                 º±±
±±º          ³      3 - Salvar como pedido                                º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ LOJA701                                                    º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7TudOk( nTipo )

Local lRet 			:= .T. 																		// Retorno da Funcao
Local nX 			:= 0   																		// Var. Auxiliar
Local nY 			:= 0   																		// Var. Auxiliar
Local lApagados     := .T.                             											// Var. que verifica se todos os itens nao estao deletados
Local nLen          := Len( aCols )					   											// Len aCols
Local nPosProd		:= aPosCpo[Ascan(aPosCpo,{|x| Alltrim(Upper(x[1])) == "LR_PRODUTO"})][2]	// Posicao da codigo do produto
Local lLJ7030T		:= ExistTemplate("LJ7030") 													// Template
Local lLJ7030		:= ExistBlock("LJ7030")														// Ponto de Entrada
Local nPosEntr		:= aPosCpo[Ascan(aPosCpo,{|x| Alltrim(Upper(x[1])) == "LR_ENTREGA"})][2]	// Posicao da codigo do produto
Local nPosResP		:= Ascan(aPosCpoDet,{|x| Alltrim(Upper(x[1])) == "LR_RESERVA"})			// Posicao Reserva
Local cMsg			:= ""																		// Mensagem de validacao do campo Entrega
Local lEntrega		:= .F.																		// Se altera o conteudo do campo LR_ENTREGA para Nao.
Local nPosCpo		:= 0																		// Posicao do Campo LR_ENTREGA no aHeader

Local nPosItem		:= 0																		// Posicao do Campo LR_ITEM no aHeader
Local nPosProduto	:= 0																		// Posicao do Campo LR_PRODUTO no aHeader
Local nPosOrcRes    := 0																		// Posicao do Campo LR_ORCRES no aHeader

Local lLj7048		:= ExistBlock("LJ7048")														// Verifica se existe o Ponto de Entrada que permite Finalizar a Venda sem efetuar a reserva
Local lReserva		:= .F.																		// Retorno do Ponto de Entrada LJ7048
Local NAnt			:= 0
Local cMensagem		:= ""
Local nPosMostruario:= AScan(aHeader,{|x| AllTrim(x[2]) == "LR_VDMOST" })						// Tipo, mostruario ou saldao
Local nPosObsMostrua:= AScan(aHeader,{|x| AllTrim(x[2]) == "LR_VDOBS" })						// Observacao, mostruario ou saldao
Local cCampo		:= ""																		// Nome do campo em memoria sem a identificao M->
Local lVAssConc	    := LjVassConc()														   		// Indica se o cliente utiliza a Vda Assistida Concomitante
Local lMVLJPRDSV   	:= SuperGetMv("MV_LJPRDSV",.F.,.F.)											// Verifica se esta ativa a implementacao de venda com itens de "produto" e itens de "servico" em Notas Separadas
Local nPosVlrISS	:= Ascan(aPosCpoDet,{|x| Alltrim(Upper(x[1])) == "LR_VALISS"})				// Posicao do Valor de ISS
Local nValorISS 	:= 0 																		// Valor de ISS

Local lFTVD7030T		:= ExistTemplate("FTVD7030") 													// Template
Local lFTVD7030		:= ExistBlock("FTVD7030")														// Ponto de Entrada
Local lFTVD7048		:= ExistBlock("FTVD7048")														// Verifica se existe o Ponto de Entrada que permite Finalizar a Venda sem efetuar a reserva
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Tratamento para e-Commerce      ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Local lECommerce := SuperGetMV("MV_LJECOMM",,.F.) .And. FindFunction("LJ862ECAuto") .And. LJ862ECAuto()
Local nFocus	 := 0
Local lIntGC	:= .F.	//Sinaliza se possui integracao MIL(Gestao Concessionaria)
Local cLJRESER 		:= SuperGetMV("MV_LJRESER ",,"1") //Controla como será realizada a reserva de produtos da venda. 1=Ao pressionar o botão F11; 2=Na gravação do orçamento; 3=Na gravação da venda.
Local aAux := {}
Local nI := 0
Local nPosFor := 0
Local nMaxParcel :=0
Local nPosDelete	:= Len(aHeader)+1
Local lEmitSAT		:= LjUseSat()
//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida
Local nPosDtLojaRes	:= Ascan(aPosCpoDet,{|x| Alltrim(Upper(x[1])) == "LR_LOJARES"})			// Posicao do codigo da reserva
Local lEmitNfce		:= LjEmitNFCe()// Sinaliza se utiliza NFC-e
Local lECCia		:= SuperGetMV("MV_LJECOMM",,.F.) .AND. SuperGetMV("MV_LJECOMO",,.F.) .AND. ( SL1->L1_ECFLAG == "1"  .OR. (  ( ExistFunc("Lj901Auto") .and. Lj901Auto() ) ) )
Local lIntegDef	:= If(Type("lAutoExec") == "L", lAutoExec, .F.) .And. FWHasEAI("LOJA701",, .T., .T.) .AND. Lj701GtInD() //Integracao via Mensagem Unica

Default nTipo 		:= 0

If Type("oGetva") <> 'U'
	nFocus := Getfocus(oGetva:obrowse)
EndIf


//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Checar se existem itens cadastrados no aCols                               ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If ( nLen <= 0 ) .OR. ( ( nLen == 1 ) .AND. Empty( aCols[1][nPosProd] ) )
	If !lAutoExec
		MsgStop(STR0016) //"Para confirmar a gravação, é necessário que haja produtos cadastrados!"
	Else
		ConOut(STR0016)
		Help( " ", 1, "Help",, STR0016, 1, 0 )
	EndIf
	lRet := .F.
	If Type("oGetva") <> 'U'
		oGetva:obrowse:setFocus(nFocus)
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Verifica se existe alguma celula em edicao³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lRet .AND. !lAutoExec
	cCmpo	:= Replace(ReadVar(),"M->", "")
	If !Empty(cCmpo) .AND. aScan( oGetVA:AALTER, cCmpo ) <> 0
		lRet :=	.F.
	EndIf
Endif

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Chamada do Ponto de Entrada para uso de Template               ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lRet .AND. lLJ7030T .AND. !lFtvdVer12
	lRet := ExecTemplate( "LJ7030", .F., .F., { 2 } )
	If ValType(lRet) <> "L"
		lRet := .T.
	EndIf
EndIf

If lRet .AND. lFTVD7030T .AND. lFtvdVer12
	lRet := ExecTemplate( "FTVD7030", .F., .F., { 2 } )
	If ValType(lRet) <> "L"
		lRet := .T.
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Chama o ponto de entrada na LinOk                              ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lRet .AND. lLJ7030 .AND. !lFtvdVer12
	lRet := Execblock( "LJ7030", .F., .F., { 2 , nTipo } )
	If ValType(lRet) <> "L"
		lRet := .T.
	EndIf
EndIf

If lRet .AND. lFTVD7030 .AND. lFtvdVer12
	lRet := Execblock( "FTVD7030", .F., .F., { 2 , nTipo } )
	If ValType(lRet) <> "L"
		lRet := .T.
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Checar se existe  alguma forma de pagamento definida                       ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
lIntGC      := IIf((SuperGetMV("MV_VEICULO",,"N")) == "S",.T.,.F.)
If lRet
	If nTipo == 1 .AND. Lj7T_TotPar(2)=0
		If !lIntGC .or. !( FindFunction("FM_PILHA") .and. FM_PILHA("VEIXA") )
			If !lAutoExec
				MsgStop(STR0082) //"Para confirmar a gravação, é necessário que haja definido forma de pagamento"
			Else
				ConOut(STR0082)
				Help( " ", 1, "Help",, STR0082, 1, 0 )
			EndIf
			lRet := .F.
		EndIf
	EndIf 
    //ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
    //³ Checar quantidade de parcelas                                                                                ³
    //³ - Se o paraÂmetro MV_1DUP for igual a "A" a parcela se limita em 26x, poi vai de A....Z                      ³
    //³ - Se o paraÂmetro MV_1DUP for diferente de "A" e o tamanho do campo no SX3 for igual 1 , parcela vai de 1...9³ 
    //³    A....Z | a.....z  se limitando a 61x                                                                      ³
    //³ - Fora essas condicoes e Respeitado o tamanho do campo no SX3 para determinar a quantidade de parcelas       ³
    //³           Exemplo: E1_PARCELA = 2  parcelas de 1 .......99                                                   ³
    //³           Esta regra se sequenciamento e igual a funcao MaParcela() e utiliza o Soma1                        ³ 
    //ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ  
    If TamSX3("E1_PARCELA")[1] == 1
        If SuperGETMV("MV_1DUP")="A"
            nMaxParcel := 26
        Else
            nMaxParcel := 60        
        EndIf
    Else
        nMaxParcel := 99        
    Endif
    for nI := 1 to len (aPgtos)
        nPosFor := aScan(aAux, {|x| x[1]== aPgtos[nI][_FORMAPGTO]} )
        If nPosFor > 0
            aAux[nPosFor][2] ++
            If aAux[nPosFor][2] > nMaxParcel
                MsgAlert(STR0391) //"Quantidade de parcelas superior ao permitido. Verifique as configurações do ParÂmetro MV_1DUP e o tamanho do campo E1_PARCELA"
                lRet := .F.
                exit
            EndIf
        Else
          Aadd(aAux, {aPgtos[nI][_FORMAPGTO],1 } )
        EndIf
    next nI
	
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Checar se existe "Recarga de Celular" efetuada                             ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lRet .And. nTipo == 1
	If Lj7RCStatus() //Verifica se foi efetuada "Recarga de Celular"
		MsgAlert(STR0287) //"Não é permitido salvar como orçamento quando efetuado Recarga de Celular."
		lRet := .F.
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Checar se existe "Recarga de Cartao Presente" (Gift Card) efetuada         ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lRet .And. nTipo == 1 .And. FindFunction("Lj7CP_OK") .And. Lj7CP_OK() //Verifica se permite utilizar a implementacao de Cartao Presente (Gift Card)
	If Lj7CPGetSt()=="S" //Verifica se foi efetuada "Recarga de Cartao Presente" (Gift Card)
		MsgAlert(STR0340) //"Não é permitido salvar como orçamento quando é efetuada uma Recarga de Cartão Presente."
		lRet := .F.
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Checa os campos obrigatorios da Getdados e se todos os itens estao apagados³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lRet
	For nX := 1 To Len(aCols)
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Verifico se o registro nao esta deletado³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If ! aCols[nX][nPosDelete]

			lApagados := .F. //Existem registros válidos

			For nY := 1 to (nPosDelete-1)
			    If X3Obrigat( Alltrim(aHeader[nY][2]) ) .AND. Empty( aCols[nX][nY] )
			    	lRet := .F.
			    	Exit
				EndIf
			Next nY

			If lRet
				//Caso esteja ativa a implementacao de venda com itens de "produto" e itens de "servico" em Notas Separadas e, estiver ativa tbm a venda
				// concomitante, o usuario deve ser avisado que os itens de "produto" e itens de "servico" nao serao gerados em notas separadas, pois ja foram impressos no Cupom
				If lMVLJPRDSV .And. lVAssConc
					If aColsDet[nX][nPosVlrIss] <> Nil .And. aColsDet[nX][nPosVlrIss] > 0
						nValorISS += aColsDet[nX][nPosVlrIss]
					EndIf
				EndIf

				//Validacao produto MOSTRUARIO ou SALDAO
				If nPosMostruario > 0 .And. nPosObsMostrua > 0 .And. !aCols[nX][nPosDelete] .And. aCols[nX,nPosMostruario] <> "N" .And. !Empty(aCols[nX,nPosMostruario]) .And. Empty(aCols[nX,nPosObsMostrua])
					If !lAutoExec
						Aviso(STR0196,STR0197,{"Ok"},2)	 //"Produto Mostruário/Saldão"#"Ao informar uma venda de um item de mostruário ou saldão, é obrigatório informar a observação do item."
					Else
						Conout(STR0196 + " - " + STR0197)	 //"Produto Mostruário/Saldão"#"Ao informar uma venda de um item de mostruário ou saldão, é obrigatório informar a observação do item."
						Help( " ", 1, "Help",, STR0196 + " - " + STR0197, 1, 0 )
					Endif
					lRet := .F.
					Exit
				EndIf

				If FindFunction("Lj7HasDtEM") .AND.  Lj7HasDtEM()
					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³Valida a data de entrega e montagem.³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					NAnt := N
					N := nX
					lRet := If( !Lj7ValEntr(,@cMensagem), .F., lRet )
					lRet := If( !Lj7ValMont(,@cMensagem), .F., lRet )

					If !lRet
						If lAutoexec
							Conout( cMensagem )
							Help( " ", 1, "Help",, cMensagem, 1, 0 )
						Else
							Alert( cMensagem )
						Endif
					EndIf
					N := NAnt

					Loop
				EndIf
			EndIf
		EndIf

		If !lRet
			If !lAutoExec
				Help(1," ","OBRIGAT")
			EndIf
			Exit
		EndIf
	Next nX

	If lApagados
		If !lAutoExec
			MsgStop( STR0016 ) //"Para confirmar a gravação, é necessário que haja produtos cadastrados!"
		Else
			ConOut( STR0016 )
			Help( " ", 1, "Help",, STR0016, 1, 0 )
		EndIf
		lRet := .F.
	EndIf

EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Verifica se foi utilizada o conceito de Seriais, caso positivo, verificar³
//³se os campos estão devidamente cadastrados antes de gravar o             ³
//³orcamento como Venda.                                                    ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If ( lRet ) .AND. ( nTipo == 2 .Or. nTipo == 1  ) .AND. !lECCia
	For nX := 1 To Len( aColsDet )
		If ! aCols[nX][Len(aCols[nX])]
			If !lMvLjPdvPa .AND. !Lj7Serial(.T.,nX)
				lRet := .F.
				Exit
			EndIf
		EndIf
	Next nX
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Procedimento para preencher o LR_ENTREGA para "N"³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If ( lRet ) .AND. nPosEntr > 0 .And. ( cLJRESER == "1" .Or. ( IsInCallStack("LJ7GRAVACAO") .And. ( (nTipo == 1 .And. cLJRESER=="2") .Or. (nTipo == 2 .And. cLJRESER=="3") ) ) ) .AND. !lECCia
	For nX := 1 To Len(aCols)
		If !aCols[nX][Len(aCols[nX])]
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Retira Posterior ou Entrega CD.³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If Empty(aColsDet[nX][aPosCpoDet[nPosResP][2]]) .AND. !(Empty(aCols[nX][nPosEntr]) .OR. aCols[nX][nPosEntr] == "2") 
				If lLj7048 .AND. !lFtvdVer12
					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³Determina se deve permitir a seleção do campo Entrega, sem³
					//³efetuar as reservas.                                      ³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					lReserva := ExecBlock( "LJ7048", .F., .F., {aCols[nX]})
					If lReserva
						lEntrega := .T.
						Exit
					Endif
				ElseIf !lFtvdVer12
					lEntrega := .T.
					Exit
				EndIf
				If lFTVD7048 .AND. lFtvdVer12
					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³Determina se deve permitir a seleção do campo Entrega, sem³
					//³efetuar as reservas.                                      ³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					lReserva := ExecBlock( "FTVD7048", .F., .F., {aCols[nX]})
					If lReserva
						lEntrega := .T.
						Exit
					Endif
				ElseIf lFtvdVer12
					lEntrega := .T.
					Exit
				EndIf
			EndIf
		EndIf
	Next nX
EndIf

If lEntrega
	nPosCpo := aScan(aHeader, { |x| AllTrim(x[2]) == "LR_ENTREGA" } )
	If nPosCpo > 0
		//"O campo '"	STR0123
		//"' da grade de itens só tem efeito para itens com reserva. Para efetuar reservas utilize a opção 'Efetuar Reserva (F11)' do botão Estoque. O conteúdo do campo '" STR0124
		//"' será alterado para 'Não'. Deseja continuar?" STR0125

		cMsg := STR0123 + AllTrim(aHeader[nPosCpo][1]) + STR0124 + AllTrim(aHeader[nPosCpo][1]) + STR0125

		If lAutoExec .Or. (!lAutoExec .And. MsgYesNo(cMsg,STR0015))     //Atenção
			//AUTRESERVA com o codigo da Loja que deverá ser utilizada na reserva dos itens
			If !lIntegDef
				If lAutoExec
					If Type("M->AUTRESERVA") == "C" .AND. !Empty(M->AUTRESERVA)
						LJ7BtnRes(1)
					Else
						Aviso( STR0008, STR0247,{STR0009} ) //"Atenção"###"Para efetuar reservas através de execução automática informe o índice AUTRESERVA com a Loja a ser utilizada."###"Ok"
					EndIf
				EndIf
				For nX := 1 To Len(aColsDet)
						If !aColsDet[nX][Len(aColsDet[nX])]
							If Empty(aColsDet[nX][aPosCpoDet[nPosResP][2]]) .AND. !(Empty(aCols[nX][nPosEntr]) .OR. aCols[nX][nPosEntr] == "2")
								aCols[nX][nPosEntr]	 := "2"
							EndIf
						EndIf
				Next nX
			EndIf
		Else
			lRet := .F.
		EndIf
	EndIf
EndIf

If IsInCallStack("LJ7RunGrv") .AND. lAutoExec .AND. !(lFtvdVer12 .OR. lECommerce) .And. Type("M->AUTRESERVA") == "U" //tratamento para reserva via ExecAuto
	If Ascan(aColsDet,{|x| AllTrim(x[nPosDtLojaRes]) <> ""}) > 0  	//Verifica se possui algum item para reserva, se sim, chama rotina e retorno fica vinculado se houve ou não sucesso no processo de reservar o item
		lRet := LJ7BtnRes(1)
	EndIf
EndIf

/*	Se for NFC-e e ela possuir frete e nao tiver nenhum item Retira Posterior ou Entrega, consideramos uma Entrega a Domicilio.
Nesse caso, validaremos se todos os campos para a emissao da tag <enderDest> estao preenchidos	*/
If lRet .AND. nTipo <> 2 .AND. nPosEntr > 0 .AND. ((lEmitNFCe .Or. lIsPafNfce) .AND. !lEmitSAT) .AND. Type("M->LQ_FRETE")=="N" .AND. M->LQ_FRETE > 0
	If aScan( aCols, {|x| !x[nPosDelete] .AND. !(Empty(x[nPosEntr]) .OR. x[nPosEntr] == "2")} ) < 1	//nao existe reserva para Retira Posterior e Entrega
		lRet := LjV65Frete( M->LQ_CLIENTE, M->LQ_LOJA )
	EndIf
EndIf

//Caso esteja ativa a implementacao de venda com itens de "produto" e itens de "servico" em Notas Separadas + venda concomitante e,
// se existir algum item de servico, avisa o usuario que os itens de "produto" e itens de "servico" nao serao gerados em notas
// separadas, pois ja foram impressos no Cupom
If lRet .And. lMVLJPRDSV .And. lVAssConc .And. nValorISS > 0 .And. nTipo == 2 .And. !lIsPafNfce
	If lAutoExec .Or. (!lAutoExec .And. MsgYesNo(STR0275 +Chr(13)+Chr(13)+ STR0276,STR0015)) //"Na venda concomitante não é possível separar os itens de produto e itens de serviço em notas distintas, pois os itens já foram impressos no cupom." ### "Deseja finalizar a venda assim mesmo?" ### Atenção
		lRet := .T.
	else
		lRet := .F.
	EndIf
EndIf

If cPaisLoc == "ARG" .And. SL1->(ColumnPos("L1_ADIC5")) > 0 .And. SLQ->(ColumnPos("LQ_ADIC5")) > 0 .And. nTipo = 2
	lRet := LjValRG3668()
EndIf

Return lRet

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³Lj7ValDel ºAutor  ³ Vendas Cliente     º Data ³  27/07/02   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Valida e efetua as alteracoes dos valores da Array padrao  º±±
±±º          ³ caso haja uma delecao do produto. (MsGetDados Principal)   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ lExp1 := Determina se envia o cancelamento para o ECF	  º±±
±±º          ³          quando for concomitante							  º±±
±±º          ³ lExp2 := Determina se faz ou nao o controle do lP7VlDev    º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ LOJA701                                                    º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7ValDel( lCancECF, lContrPassou, lCancAuto, lEndVendCC,;
 					lDelMarg, cCodKit, cItOri)
Local lRet				:= .T.																		// Retorno da funcao
Local nAuxTotal			:= 0																		// Auxiliar para calculo do subtotal e total
Local nAuxQuant         := 0																		// Auxiliar para totalizador de quantidade de itens
Local nPosItem			:= aPosCpo[Ascan(aPosCpo,{|x| Alltrim(Upper(x[1])) == "LR_ITEM"})][2]		// Posicao do Codigo do item
Local nPosVlItem		:= aPosCpo[Ascan(aPosCpo,{|x| Alltrim(Upper(x[1])) == "LR_VLRITEM"})][2]	// Posicao do Valor do item
Local nPosProd			:= aPosCpo[Ascan(aPosCpo,{|x| Alltrim(Upper(x[1])) == "LR_PRODUTO"})][2]	// Posicao da codigo do produto
Local nPosQuant			:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_QUANT"})][2]	// Posicao da Quantidade
Local nGarant			:= Ascan(aPosCpoDet,{|x| Alltrim(Upper(x[1])) == "LR_GARANT"})			// Posicao da Garantia Estendida
Local nPosNSerie        := Ascan(aPosCpoDet,{|x| Alltrim(Upper(x[1])) == "LR_NSERIE"})			// Posicao do Numero de Serie do Produto
Local nPosDtReserva		:= Ascan(aPosCpoDet,{|x| Alltrim(Upper(x[1])) == "LR_RESERVA"})			// Posicao do codigo da reserva
Local nPosDtLojaRes		:= Ascan(aPosCpoDet,{|x| Alltrim(Upper(x[1])) == "LR_LOJARES"})			// Posicao do codigo da reserva
Local nPosDtLocal		:= Ascan(aPosCpoDet,{|x| Alltrim(Upper(x[1])) == "LR_LOCAL"})				// Posicao do local (armazem)
Local lDeleted			:= aCols[n][Len(aCols[n])]     											// Coluna que controla se o item já está deletado
Local nX				:= 0																		// Utilizada em lacos
Local lAtuSaldo			:= .T.                      												// Determina se o saldo deve ser atualizado - Localizacoes
Local cMsg				:= ""																		// Msg que sera mostrada no rodape da tela da Venda Assistida
Local lVAssConc	 		:= LjVassConc()																// Indica se o cliente utiliza a Vda Assistida Concomitante
Local lLJ7037t			:= ExistTemplate( "LJ7037" )												// Ponto de entrada antes das validacoes do sistema
Local lLJ7037			:= ExistBlock( "LJ7037" )													// Ponto de entrada antes das validacoes do sistema
Local lRetPE			:= .T.																		// Retorno do ponto de entrada LJ7037
Local nTamLR_RESERVA	:= TamSx3("LR_RESERVA")[1]													// Tamanho do campo LR_RESERVA
Local nTamLR_LOJARES	:= TamSx3("LR_LOJARES")[1]													// Tamanho do campo LR_LOJARES
Local cSup				:= Space( 15 )																// Variavel utilizada para senha de superior.
Local cTipoCalc			:= AllTrim(SuperGetMV("MV_LJTPCAL",,"3"))									// Tipo de Calculo de desconto
Local lAtuImpFis		:= .T.															            // Atualiza os impostos e valores totais
Local oKeyMotivo		:= Nil																		// Procura motivo de desconto
Local nPosDescPro		:= Ascan(aPosCpoDet,{|x| Alltrim(Upper(x[1])) == "LR_DESCPRO"})			// Posicao do descontro proporcinal
Local nPosPrcTab		:= Ascan(aPosCpoDet,{|x| Alltrim(Upper(x[1])) == "LR_PRCTAB"})				// Posicao do preco de tabela
Local nPosValDesc  		:= aPosCpo[Ascan(aPosCpo,{|x| Alltrim(Upper(x[1])) == "LR_VALDESC"})][2]	// Posicao da quantidade
Local nPosVlDescP  		:= aPosCpo[Ascan(aPosCpo,{|x| Alltrim(Upper(x[1])) == "LR_DESC"})][2]       // Valor do desconto em percentual
Local nPosQtda  		:= aPosCpo[Ascan(aPosCpo,{|x| Alltrim(Upper(x[1])) == "LR_QUANT"})][2]	// Posicao da quantidade
Local nPosVrUnit		:= aPosCpo[Ascan(aPosCpo,{|x| Alltrim(Upper(x[1])) == "LR_VRUNIT"})][2]	// Posicao do Valor unitario
Local nY				:= 0																		// Utilizada em lacos
Local nBkLine			:= n
Local nBKP				:= 0
Local lVendaPerdida		:= .F. 												// Habilita funcionalidade de vendas perdidas
Local lVepe				:= .F.												//Retorno do preenchimento da tela de venda perdida.
Local nItemVp			:= 0
Local cTpComiss			:= SuperGetMv("MV_LJTPCOM",,"1")		// Tipo de calculo de comissao utilizado (1-Para toda a venda (padrao),2-Por item)
Local cVend				:= ""									// Vendedor gravado no item                                                                     // Numero do item de venda não vendido.
Local nPosVend			:= 0 									// Posicao do vendedor
Local lCenVenda			:= SuperGetMv("MV_LJCNVDA",,.F.)											// Indica se existe integracao com cenario de vendas
Local aDesProCoP        := {}
Local nPosIt            := 0
Local nVlrItemCF		:= 0																		//Valor do item a ser impresso no cupom fiscal (somente LR_Entrega=Retira)
Local nPosEntrega		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_ENTREGA"})][2]	// Posicao da Unidade de Medida
Local cEntrega			:= ""																		// Controle do tipo de entrega do item
Local lExLegSP10   		:= ExistFunc("Lj950SP10OK")										  		// Verifica a existencia da funcao que valida a legislacao paulista que limita o cupom fiscal em 10.000,00
Local lExTotalCF		:= ExistFunc("LJXTotalCF")												// Verifica a existencia da funcao que calcula o total do cupom fiscal
Local lIsRecCel 		:= .F.																   		// Indica que eh produto "Recarga de Celular"
Local lIsRecCP 			:= .F.																   		// Indica que eh produto "Recarga de Cartao Presente" (Gift Card)
Local lFTVD7037t		:= ExistTemplate( "FTVD7037" )												// Ponto de entrada antes das validacoes do sistema
Local lFTVD7037			:= ExistBlock( "FTVD7037" )													// Ponto de entrada antes das validacoes do sistema
Local nAuxSuframa      	:=  0																		//Auxiliar para calculo do Suframa
Local lGE		  		:= LjUP104OK()								// Validação do Conceito Garantia Estendida
Local cMvLjTGar		    := SuperGetMV("MV_LJTPGAR",,"GE")											// Se trabalha com GE
Local lSFinanc			:= ExistFunc("Lj7SfTela") .AND. AliasIndic("MG8") .AND. SuperGetMV("MV_LJCSF",,.F.)// Validação do Conceito Servico Financeiro
Local cMvLjTSf   		:= SuperGetMV("MV_LJTPSF",,"SF")											// Define se é tipo SF
Local cB1_TIPO			:= ""
Local lL2IGarItem		:= SLR->(ColumnPos("LR_ITEMGAR")) > 0			// Verifica a existencia do campo L2_VLGAPRO dias de garantia
Local nPGarItem			:= iIf(lL2IGarItem, aScan(aHeader,{|x| Upper(Alltrim(x[2])) == "LR_ITEMGAR"}) ,0)
Local nPosPafMd5 		:= Ascan(aPosCpoDet,{|x| Alltrim(Upper(x[1])) == "LR_PAFMD5"})
Local nPosSublote		:= aScan(aHeaderDet,{|x| Alltrim(Upper(x[2]))=="LR_NLOTE"})				// Posicao do subLote
Local nPosLote			:= aScan(aHeaderDet,{|x| Alltrim(Upper(x[2]))=="LR_LOTECTL"})				// Posicao do Lote
Local nPosEndereco		:= aScan(aHeaderDet,{|x| Alltrim(Upper(x[2]))=="LR_LOCALIZ"})				// Posicao do Endereco
Local nPosNumSerie		:= aScan(aHeaderDet,{|x| Alltrim(Upper(x[2]))=="LR_NSERIE"})				// Posicao do num de serie
Local lCentPDV			:= IIf( ExistFunc("LjGetCPDV"), LjGetCPDV()[1] , .F. )					// Central de PDV
Local nPosItGar			:= 0																		// Posicao Item Garantia
Local nItemGar			:= 0																		// Valor Item Garantia
Local nPosItSer			:= 0																		// Posicao Item Servico
Local nItemSer			:= 0																		// Valor Item Servico
//³Release 11.5 - Cartao Fidelidade³
Local lLjcFid 			:= SuperGetMv("MV_LJCFID",,.F.) .AND. CrdxInt() //Indica se a recarga de cartao fidelidade esta ativa
//³Release 11.5 - Controle de Formularios ³
//³Paises:Chile/Colombia - F1CHI		  ³
Local lCFolLocR5		:= SuperGetMv("MV_CTRLFOL",,.F.) .AND. cPaisLoc$"CHI|COL" .AND. !lFiscal
Local cSigEspFo			:= ""					// Especie (SIGLA) do formulario informado pelo usuario no inicio da venda
Local lAltOrc	  		:= (SuperGetMV("MV_LJCHGTP",,2) == 1 .AND. SuperGetMV("MV_LJALTEN", NIL, .F.))	// Verificacao dos parametros de alteracao
Local lLog4         	:= SuperGetMv("MV_LJRECIT", , .F.) .And. Subs(LJGetProfile("LOGERRO"),4,1) == "S"  // Log de Recuperacao, grava as parcelas
Local lMargem       	:= SuperGetMV("MV_LJMARGE",,.F.) 				// Valida se considera a margem minIma no venda assistida.
Local aSB1Ord			:= {}
Local nPosValePre		:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_VALEPRE"})	// Posicao do codigo do Vale Presente
Local aRet 				:= {}
Local lTdsDel			:= .T.
Local nFor				:= 0
Local aVidaLink			:= LJGDadosVL()						//Dados do PBM Funcional Card
Local nPosPBM			:= 0								//Posição encontrada da busca do produto para exclusão
															//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
Local lFtvdVer12	:= LjFTVD()		 						//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida
Local aButtons 		:= {	{.F.,Nil},;  //1 - Copiar		//Variavel utilizada pela fução FWExecView
							{.F.,Nil},;	 //2 - Recortar
							{.F.,Nil},;	 //3 - Colar
							{.F.,Nil},;  //4 - Calculadora
							{.F.,Nil},;	 //5 - Spool
							{.F.,Nil},;  //6 - Imprimir
							{.T.,Nil},;	 //7 - Confirmar	
							{.F.,Nil},;	 //8 - Cancelar
							{.F.,Nil},;	 //9 - WalkTrhough
							{.F.,Nil},;	 //10 - Ambiente
							{.F.,Nil},;	 //11 - Mashup
							{.F.,Nil},;	 //12 - Help
							{.F.,Nil},;	 //13 - Formulário HTML
							{.F.,Nil}	}//14 - ECM
Local nRet 			:=  1				 //Variavel de controle de Whilli para fechamento da tela de Motivo de venda perdida.
Local lPBMDesc		:= ExistTemplate("DroPbmDe") .AND. T_DroPbmDe()
Local nPosCodBar	:= aScan(aHeaderDet,{|x| Alltrim(Upper(x[2]))=="LR_CODBAR"})				// Código de Barras
Local lNovRegDesc	:= .F.

Default cCodKit := ""
Default cItOri  := ""

Default lCancECF			:= .T.				// Determina se envia o cancelamento para o ECF quando for concomitante
Default lContrPassou		:= .T.				// Determina se faz ou nao o controle do lP7VlDev
Default lCancAuto       	:= .T.	 			// Cancelamento automatico do item não checa permissão do usuario
Default lEndVendCC		:= .F.				// Finaliza Venda Concomitante
Default lDelMarg            := .F.              // Verifica se esta deletando o item na validação da margem minima

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³A variavel lP7VlDev foi criada devido a um bug na funcao de    ³
//³delecao que estah sendo chamada 2 vezes.                       ³
//³Quando esta funcao eh chamada por dentro do fonte nao eh       ³
//³necessario fazer o controle do lP7VlDev e esta variavel tem que³
//³iniciar a funcao como False e sair da funcao como False        ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Static lP7VlDev		:= .F.
Static lValidSenha	:= .F.

//Caso nao tenha item registrado, nao tem o que deletar
If n == 0 .OR. Empty( aCols[n][nPosProd] )
	lRet := .F.
EndIf

//Quando item ja foi deletado(lDeleted) e não concomitante(lVAssConc), valida se item foi cancelado no orçamento e não permite reativar/"descancelar". Item cancelados na Retaguarda possuem PAFMD5 preenchido
//Motivo: Se utiliza validacao de estoque na retaguarda, não valida estoque na importação de item deletado
If lRet .AND. lDeleted .AND. !lVAssConc .AND. LjNfPafEcf(SM0->M0_CGC) .AND.;
	lMvljpdvpa .AND. nPosPafMd5 > 0 .AND. !Empty(aColsDet[n][nPosPafMd5]) .AND. !lFtvdVer12 .AND.;
	lHomolPaf

	lRet := .F.

	If !lAutoExec
		MsgStop(STR0314) //"Conforme previsto no ATO COTEPE/ICMS 0608, o item cancelado no Orçamento deve ser cancelado na emissão do Cupom Fiscal. Item não poderá ser reativado."
	Else
		ConOut(STR0314) //"Conforme previsto no ATO COTEPE/ICMS 0608, o item cancelado no Orçamento deve ser cancelado na emissão do Cupom Fiscal. Item não poderá ser reativado."
	EndIf

EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Funcao que verifica se o usuario que esta vinculado ao vendedor do item e o mesmo que esta logado no momento.³
//³Autoriza ou nao deletar o item, verifica integridade de cadastros e lancamentos.								³
//³Realizado controle atraves da variavel lValidSenha e juncao entre as Funcoes Lj7VldUs e Lj7VldVp 			³
//³para que seja verificado somente uma vez de acordo com o bug na funcao de delecao que esta sendo 			³
//³chamada 2 vezes e gera inconsistencia.   																	³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lRet .AND. !(lValidSenha)
	lValidSenha := .T.
		If cTpComiss== "3"
			If !Lj7VldUs()
				lRet 	:= .F.
				Return lRet
			Else
				lP7VlDev := .F.
			EndIf
			lVendaPerdida := Lj7VldVp()
		Else
			lVendaPerdida := Lj7VldVp()
		Endif
ElseIf lRet .AND. (lValidSenha)
	lValidSenha := .F.
	If lContrPassou
		lP7VlDev := .T.
	EndIf
EndIf

//Quando Retaguarda PAF-ECF nao deve enviar o cancelamento para o ECF
If lRet .AND. (LjNfPafEcf(SM0->M0_CGC) .AND. !lMvljpdvpa) .OR.;
	(ExistFunc("Lj7VPNew") .AND. Lj7VPNew() .AND. nPosValePre > 0 .AND. Len(aColsDet) >= n .AND. !Empty(aColsDet[n][nPosValePre])) .OR.;
	(ExistFunc("Lj7CP_OK") .And. Lj7CP_OK() .And. Lj7CPGetSt()=="S")
	lCancECF := .F.
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Se for multiplos vendedores, o campo do vendedor estara  ³
//³visivel no getdados, logo a posicao no array sera valida.³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lRet .AND. cTpComiss <> "1"
	nPosVend:= Ascan(aHeader,{|x| Alltrim(Upper(x[2])) == "LR_VEND"})
Endif

If lRet .AND. lDelMarg
	lP7VlDev    := .F.
	lValidSenha	:= .F.
EndIf

If lRet .AND. !lP7VlDev
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Ponto de entrada para validar a delecao da linha antes da     ³
	//³ chamada do cancelamento da concomitancia                      ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If lFtvdVer12
		If lFTVD7037
			LjGrvLog( NIL, " Antes da Execução do Ponto de Entrada FTVD7037")
			lRetPE := ExecBlock( "FTVD7037", .F., .F. )
			LjGrvLog( NIL, " Depois da Execução do Ponto de Entrada FTVD7037",lRetPE)
			If ValType( lRetPE ) == "L"
				lRet := lRetPE
			EndIf
		EndIf

		If lFTVD7037t
			LjGrvLog( NIL, " Antes da Execução do Ponto de Entrada FTVD7037")
			lRetPE := ExecTemplate( "FTVD7037", .F., .F. )
			LjGrvLog( NIL, " Depois da Execução do Ponto de Entrada FTVD7037",lRetPE)
			If ValType( lRetPE ) == "L"
				lRet := lRetPE
			EndIf
		EndIf		
	Else

		If lLJ7037t
			LjGrvLog( NIL, " Antes da Execução da Template Function LJ7037")
			lRetPE := ExecTemplate( "LJ7037", .F., .F. )
			LjGrvLog( NIL, " Depois da Execução da Template Function LJ7037",lRetPE)
			If ValType( lRetPE ) == "L"
				lRet := lRetPE
			EndIf
		EndIf
	
		If lLJ7037
			LjGrvLog( NIL, " Antes da Execução do Ponto de Entrada LJ7037")
			lRetPE := ExecBlock( "LJ7037", .F., .F. )
			LjGrvLog( NIL, " Depois da Execução do Ponto de Entrada LJ7037",lRetPE)
			If ValType( lRetPE ) == "L"
				lRet := lRetPE
			EndIf
		EndIf
	EndIf

	/*Não é permitido deletar item de Venda com Reserva,         
	na operação de Altera Entrega, somente alterar o             
	campo Tipo de Entrega  confo. boletim de de implementação    
	P0186 – Alteração da Ordem de Entrega-FNC: 000000047312011 . */
	If lAltOrc .AND. lAlterOrc
		Alert (STR0296)
		lRet := .F.
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Valida se o eh para fazer as validacoes do sistema            ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If lRet

		If !Empty( aCols[n][nPosProd] ) //Continua a validacao somente se o produto estiver informado
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Verifica se o registro selecionado esta sendo deletado         ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If !aCols[n][Len(aCols[n])]
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Verifica se eh concomitante e se o usuario tem permissao para delecao.³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				If lCancAuto
					lRet := LJProfile(	7,		@cSup,		Nil,	Nil, ;
										Nil,	.T. )
				EndIf

				If lRet .And. Lj7RCPrdRC(aCols[n][nPosProd]) //Verifica se o produto eh "Recarga de Celular"
					lIsRecCel := .T. // Indica que eh produto "Recarga de Celular"
					lRet := MsgYesNo(STR0288) //"Deseja realmente excluir este ítem de Recarga de Celular?"
				EndIf

				//Faz validacao para nao permitir excluir item de Recarga de Cartao Presente, caso tenha mais de uma recarga de Cartao Presente na venda.
				If lRet .And. ExistFunc("Lj7CP_OK") .And. Lj7CP_OK() .And. Lj7CP_Ativ() .And. Lj7CP_Prod(aCols[n][nPosProd]) //Verifica se o produto eh "Recarga de Cartao Presente" (Gift Card)
					If Lj701DelCP(aCols, n, nPosProd)
						lIsRecCP := .T. // Indica que eh produto "Recarga de Cartao Presente" (Gift Card)
						lRet := MsgYesNo(STR0321) //"Deseja realmente excluir este ítem de Recarga de Cartão Presente?"
					Else
						MsgAlert(STR0322) //"Exclusão não permitida para ítem de Recarga de Cartão Presente, pois nesta venda existe mais de um item de Recarga de Cartão Presente."
						lRet := .F.
					EndIf
				EndIf

				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Verifica se existem reservas                                   ³
				//³Nao permitir deletar o item sem antes cancelar a reserva       ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				If Len( aColsDet ) >= n .AND. lRet
					//Verifca se o produto esta digitado e se a Reserva esta preenchida
					//Incluida a validacao para o codigo da Reserva diferente de "S", conforme requisitado na Lista de Presentes
					If !Empty( aCols[n][nPosProd] ) .AND. !Empty( aColsDet[n][nPosDtReserva] ) .AND. Alltrim(aColsDet[n][nPosDtReserva]) <> "S"
						If !HasTemplate("OTC")
							// "Existe uma reserva para esse produto, se for deletado a reserva será cancelada. Deseja continuar ?"
							If MsgYesNo( STR0017 )

								//Verifica se foi uma venda importada no LojaOffLine
								If !lDeleted .AND. !lVAssConc .AND. LjNfPafEcf(SM0->M0_CGC) .AND. lMvljpdvpa .AND.;
									nPosPafMd5 > 0 .AND. !Empty(aColsDet[n][nPosPafMd5])

	                                aRet := {}

	                                	//Chama rotina(RPC) para gerar arquivo na Retaguarda
	   								LjMsgRun( STR0339,,;   //"Cancelando Reserva na Retaguarda..."
	   								{ || aRet := FR271CMyCall("Lj7CancRes", {"SLJ", "SC0","SL2" }, {{aColsDet[n][nPosDtReserva]	,;	// Numero da Reserva
																aColsDet[n][nPosDtLojaRes]		,;	// Codigo da loja da reserva
																aCols[n][nPosProd]				,;	// Codigo do produto
																aColsDet[n][nPosDtLocal]			,;	// Codigo do local (armazem)
																NIL									,; 	//
																aCols[n][nPosItem]				} }, .T.  ) } )



	                            	lRet :=  ValType(aRet) == "A" .AND. Len(aRet) = 1 .AND. Len(aRet[1]) > 1 .AND. ValType(aRet[1][2]) = "L" .AND. aRet[1][2]
	                            									//Central de PDV
								ElseIf lCentPDV
									aLote := {aColsDet[n][nPosSublote] 		,;	// Lote
											  	aColsDet[n][nPosLote]    	,;	// Sublote
											  	aColsDet[n][nPosEndereco]	,;	// Endereco
											  	aColsDet[n][nPosNumSerie]	}	// Serie do Item

									aRet := Lj7CancRes(	  {{aColsDet[n][nPosDtReserva]	,;	// Numero da Reserva
														aColsDet[n][nPosDtLojaRes]			,;	// Codigo da loja da reserva
														aCols[n][nPosProd]					,;	// Codigo do produto
														aColsDet[n][nPosDtLocal]				,;	// Codigo do local (armazem)
														NIL										,;	//
														aCols[n][nPosItem]					,; 	// Item
														aLote									}} )// Array de Lotes

								Else

									aRet := Lj7CancRes(	  {{aColsDet[n][nPosDtReserva]	,;	// Numero da Reserva
															aColsDet[n][nPosDtLojaRes]		,;	// Codigo da loja da reserva
															aCols[n][nPosProd]				,;	// Codigo do produto
															aColsDet[n][nPosDtLocal]			,;	// Codigo do local (armazem)
															NIL									,; 	//
															aCols[n][nPosItem]				}} )// Item
								EndIf
								lRet := aRet[1][2]
								If !lRet
									If !lAutoExec
										MsgInfo( STR0018 )									// "A reserva não pode ser cancelada. O item não será deletado"
									Else
										Conout( STR0018 )									// "A reserva não pode ser cancelada. O item não será deletado"
									Endif
									// Validacao de modulos, P.E e Templates
									lRet := Lj7Call003(nPositem)
								Else
									// Validacao de modulos, P.E e Templates
									lRet := Lj7Call003(nPositem)
									If lRet
										//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
										//³Limpa o array onde estava o numero da reserva³
										//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
										aColsDet[n][nPosDtReserva] := Space( nTamLR_RESERVA )
										aColsDet[n][nPosDtLojaRes] := Space( nTamLR_LOJARES )
										Lj7AtuResOrc (M->LQ_NUM)
									EndIf
								EndIf
								// Validacao de modulos, P.E e Templates
								lRet := Lj7Call003(nPositem)
							Else
								lRet := .F. // Escolheu não ou teclou ESC
							EndIf
				   		Else
					   		// Validacao de modulos, P.E e Templates
							lRet := Lj7Call003(nPositem)
							If lRet
							  Lj7AtuResOrc (M->LQ_NUM)
							EndIf
				   		EndIf
					Else
					   	// Validacao de modulos, P.E e Templates
						lRet := Lj7Call003(nPositem)
					EndIf
				EndIf

				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Delecao do Item/Produto pertencente ao Array aDesProCop,³
				//³do Cenario de vendas no momento de criacao da NCC       ³
				//³ para utilização na proxima Venda/Compra pelo Cliente.  ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				If lCenVenda .AND. lRet .AND. ExistFunc("LjGetCVar")
					aDesProCoP := LjGetCVar()
					If Len(aDesProCoP) > 0
						//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
						//³Roda o "For" para posicionar no Array o produto 		³
						//³que está sendo procurado e realiza a delecao.        ³
						//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
						For nX := 1 To Len(aDesProCoP)
							nPosIt    := aCols[n][nPosItem]
							If aDesProCoP[nX][4] = nPosIt
								aDel(aDesProCop,nX)
 								//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
								//³Retorna o valor do Array atualizado através da Função LjSetCVar(A)³
								//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
 								LjSetCVar(aDesProCoP)
							EndIf
						Next nX
					EndIf
				EndIf
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//|Exclui o item no cupom fiscal somente com venda assistida concomitante e se  |
				//|estiver sendo chamada do delete da linha. Nao chama a funcao de cancelamento |
				//|se a funcao estiver sendo chamada da LJ7Prod() e houve algum erro no registro|
				//|do item                                                                      |
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				If lRet
					If lVAssConc .AND. lCancECF .And. !lIsPafNfce
						lRet := Lj7CancIt()    // Cancela o Item no cupom fiscal
					EndIf
				EndIf

				If lRet
					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³Subtrai do total dos impostos o item excluido³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					If (cPaisLoc <> "BRA" .AND. !lFtvdVer12) .OR. (cPaisLoc <> "BRA" .AND. (lAtuSaldo := Lj7RecalImp(n,4)) .AND. lFtvdVer12)

						//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
						//³Retorna o valor do preco unitario e dos itens, no aCols sem³
						//³o desconto global quando eh deletado um item no aCols.     ³
						//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
						If nRotina == 4 .AND. Lj7T_DescV( 2 ) > 0
							For nY:= 1 to Len(aCols)
								If !aCols[nY][Len(aCols[nY])]
									aCols[nY][nPosVrUnit] := Round( ((aColsDet[nY][nPosDescPro] / aCols[nY][nPosQtda]) + aCols[nY][nPosVrUnit]), 2 )
									aCols[nY][nPosVlItem] := (aColsDet[nY][nPosPrcTab] * aCols[nY][nPosQtda]) - aCols[nY][nPosValDesc]
								EndIf
							Next nY
						EndIf
						//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
						//³Retira o valor do item do SubTotal e Total                     ³
						//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
						nAuxTotal := LJ7T_Subtotal(2) - IIf( MaFisFound("IT",n), MaFisRet(n, "IT_TOTAL"), aCols[n][nPosVlItem] )
					EndIf

					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³Chama a funcao fiscal para deletar o item                      ³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			   	 	If lGE .AND. Ascan(aHeader,{|x| Alltrim(Upper(x[2])) == "LR_GARANT"}) > 0  .AND. n > 1 .AND. AllTrim(Posicione("SB1", 1, xFilial("SB1") + aCols[n][nPosProd], "B1_TIPO")) == cMvLjTGar
						nGarant		:= Ascan(aHeader,{|x| Alltrim(Upper(x[2])) == "LR_GARANT"})
						nPosItGar	:= Ascan(aHeader,{|x| Alltrim(Upper(x[2])) == "LR_ITEMGAR"})
						nItemGar 	:= Val(aCols[n][nPosItGar]) //Posicao do Item Garantia
					EndIf

					If lSFinanc .AND. Ascan(aHeader,{|x| Alltrim(Upper(x[2])) == "LR_ITEMCOB"}) > 0
						nPosItSer := Ascan(aHeader,{|x| Alltrim(Upper(x[2])) == "LR_ITEMCOB"})
					EndIf

					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³Chama a rotina para validar o desconto no total³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					If Lj7T_DescP( 2 ) > 0 .OR. Lj7T_DescV( 2 ) > 0
						If cPaisLoc == "BRA"
							LjGrvLog( NIL, "Parâmetro MV_LJTPCAL está configurado com [" + cTipoCalc + "] " + CHR(10) + CHR(13) +;
									"Esse parâmetro interfere diretamente no desconto, verifique sua documentação no TDN " +;
									"http://tdn.totvs.com/display/PROT/DT_MV_LJTPCAL")							
						EndIf
						
						lNovRegDesc := SuperGetMv("MV_LJRGDES",,.F.) .AND. RGVldTable()
							
						If lNovRegDesc
							LjGrvLog( NIL, "Parâmetro MV_LJTPCAL está configurado com [" + cTipoCalc + "] " + CHR(10) + CHR(13) +;
								" Porém com regra de desconto Varejo ativa esse parâmetro não tem efeito e o desconto será zerado" )
							Conout("Parâmetro MV_LJTPCAL está configurado com [" + cTipoCalc + "] " + CHR(10) + CHR(13) +;
								" Porém com regra de desconto Varejo ativa esse parâmetro não tem efeito e o desconto será zerado")
						EndIf
						
						If lNovRegDesc .Or. cTipoCalc == "4" .Or. cPaisLoc <> "BRA"
							Lj7ZeraDesc()
							lAtuImpFis := .T.	// Deve atualizar os valores totais e impostos
						Else
							If cTipoCalc <> "5" //Se o parâmetro for igual a "5" não abre a tela e mantem o valor de desconto.
								Lj7PergDes()
							Else
								LjGrvLog( NIL, "Parâmetro MV_LJTPCAL está configurado com [5] portanto desconto será mantido")
							EndIf
						EndIf
					EndIf

	
					MaFisDel(n, .T.)

					If !lP7VlDev .AND. lGE .AND. Ascan(aHeader,{|x| Alltrim(Upper(x[2])) == "LR_GARANT"}) > 0  .AND. n > 1 .AND. AllTrim(Posicione("SB1", 1, xFilial("SB1") + aCols[n][nPosProd], "B1_TIPO")) == cMvLjTGar
						//Deleta Item Garantia Estendida
						If !Empty(aCols[n][nGarant])
							If Posicione("SB1", 1, xFilial("SB1") + aCols[nItemGar][nPosProd], "B1_TIPO") == cMvLjTGar .AND.;
								AllTrim(aCols[n][nGarant]) == AllTrim(aCols[nItemGar][nPosProd])

								oGetVA:GoTo(nItemGar)
								MaFisDel(n, .T.)
								aCols[n, Len(aHeader)+1] := .T.
								aColsDet[n][Len(aColsDet[n])] := .T.
							EndIf

							//Retorna posicao inicial
							oGetVA:GoTo(nBkLine)
						EndIf

						//Retorna posicao inicial
						oGetVA:GoTo(nBkLine)

						//Quando o nBkLine for diferente do GoTo,
						//forço a entrar novamente no GoTo.
						If !(oGetVA:GoTo() == nBkLine)
							oGetVA:GoTo(nBkLine)
						EndIf

					ElseIf lGE .AND. nGarant > 0 .AND. n > 1 .AND. AllTrim(Posicione("SB1", 1, xFilial("SB1") + aCols[n][nPosProd], "B1_TIPO")) == cMvLjTGar
						nItemGar := Val(aCols[n][nPosItGar])

						If nItemGar > 0 .AND. AllTrim(aCols[nItemGar][nGarant]) ==  AllTrim(aCols[n][nPosProd])
							aCols[nItemGar][nGarant]		:= "" 	//Zera a Amarracao do Produto Garantia Estendida do Produto Principal
							aColsDet[nItemGar][nPosNSerie]	:= ""	//Zera o numero Serial no Produto que foi preenchido pela Garantia Estendida

							If nPGarItem > 0
								aCols[n][nPGarItem]			:= ""  // Zera Relacionamento do item garantia com Item produto
								aCols[nItemGar][nPGarItem]	:= ""  // zera Relacionamento do item Produto com Item Garantia
							EndIf
						EndIf
					EndIf


					//Recalcula o Subtotal e Desconto no Total após a exclusão de um item da grade. 
					If !lNovRegDesc .AND. cTipoCalc == "3" .AND. (Lj7T_DescP( 2 ) > 0 .OR. Lj7T_DescV( 2 ) > 0) .AND. (nDescRad == 1 .OR. nDescRad == 2) 
						Lj7T_SubTotal( 2, ( Lj7T_SubTotal(2) - MaFisRet(n, "IT_TOTAL") ))
						LjValidPer(nDescRad)
					EndIF

					//Retornado o valor do desconto no total após remover algum item da matxfis, para que seja recalculado o desconto corretamente
					//para o item que ficou mantido, caso foi selecionado a opção de manter desconto na venda.
					
					MaFisAlt("NF_DESCTOT", Lj7T_DescV(2) )			

					//Deleta Itens Servico Financeiro atrelados
					If lSFinanc .AND. Empty(aCols[n][nPosItSer])
						nBkLine := n

						For nX := 1 To Len(aCols)
							If nX <> nBkLine .AND. aCols[nX][nPosItSer] == aCols[nBkLine][nPosItem] .AND.;
								Posicione("SB1", 1, xFilial("SB1") + aCols[nX][nPosProd], "B1_TIPO") == cMvLjTSf .AND.;
								!aColsDet[nX][Len(aHeader)+1]

								oGetVA:GoTo(nX)

								MaFisDel(n, .T.)
						    	aCols[n, Len(aHeader)+1] := .T.
						    	aColsDet[n][Len(aColsDet[n])] := .T.
						    EndIf
						Next nX

						oGetVA:GoTo(nBkLine)
					EndIf

					// Deleta os itens referente ao Kit de Produto
					If Lj7IsKit(aCols[n][nPosItem], aCols[n][nPosProd],cCodKit, cItOri)
						oGetVa:oBrowse:nAt := n
						MaFisDel(n, .T.)
						aCols[n, Len(aHeader)+1] := .T.
						aColsDet[n][Len(aColsDet[n])] := .T.
					EndIf

					// Refaz os calculos e atualiza a variavel nAuxTotal
					// Devido Localizado ter um calculo diferente, foi protegido com "==BRA"
					If cPaisLoc == "BRA"
						// Marca o item do array aColsDet como deletado
						If Len( aColsDet ) >= n  .AND. !lDeleted
					  		aColsDet[n][Len(aColsDet[n])] := .T.
					  	EndIf

						Lj7T_Subtotal( 2, 0 )
						Lj7T_Total( 2, 0 )

						nAuxTotal   := 0

						// Recalculo da variavel nAuxTotal
						For nX  := 1 to Len(aColsDet)
							// Verifica se o item do aColsDet esta deletado

							If aColsDet[nX][Len(aColsDet[nX])]
								Loop
							EndIf
							// Incrementa o valor do item na variavel nAuxTotal
							nAuxTotal  += IIf(MaFisFound("IT", nX), MaFisRet(nX, "IT_TOTAL")-MaFisRet(nX, "IT_FRETE"), aCols[nX][nPosVlItem])
						Next nX

						Lj7T_Total( 2, nAuxTotal  )
						Lj7T_Subtotal( 2, nAuxTotal + Lj7T_DescV(2) )
						
						//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
						//³Retira quantidade do totalizador de quantidade                  ³
						//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

						For nX := 1 To Len(aColsDet)
							If aColsDet[nX][Len(aColsDet[nX])]
								Loop
							EndIf
							nAuxQuant += aCols[nX][nPosQuant]
						Next nX

						If lFtvdVer12
                            If MaFisRet(,"NF_SUFRAMA")
                                nDescSufr := MaFisRet(,"NF_DESCZF")
                                If Len(aTotais)>6
                                    LjVDT_SUFR(2, nDescSufr)
                                EndIf
                            EndIf						
						ElseIf ExistFunc("Lj7T_Quant")
							Lj7T_Quant( 2, nAuxQuant )
						EndIf

					Endif

					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³Ajusta o array de detalhes                                     ³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

					If Len( aColsDet ) >= n
						aColsDet[n][Len(aColsDet[n])] := .T.

						Lj7Detalhe(.F.)

						If lVendaPerdida
							//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
							//³Ao excluir um item de venda, informar os dados³
							//³do movimento de venda perdida, referente ao   ³
							//³item que deixou de ser vendido.               ³
							//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	  						If oMoviVp == NIL
		  						oMoviVp := LJCVenPer():New()
		  					EndIf

							//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
							//³Validar codigo do vendedor³
							//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				        	If cTpComiss == "1"
								cVend := M->LQ_VEND
							Else
								If nPosVend > 0
									If !Empty (aCols[n][nPosVend])
										cVend := aCols[n][nPosVend]
									Else
										cVend := M->LQ_VEND
									Endif
								Else
									cVend := M->LQ_VEND
								Endif
							EndIf

				        	oMoviVp:AddItem (n,aCols[n][nPosProd],aCols[n][nPosQtda],M->LQ_LOJA,cVend,M->LQ_CLIENTE,M->LQ_EMISSAO  )

							While nRet == 1
								nRet := FWExecView(STR0198,'LOJA740', 3, , { || lVepe:=.T., lVepe},,30,aButtons)
							End

				        	If !lVepe
								If !lAutoExec
									MsgAlert(STR0199)//"O movimento de venda perdida para este item não será gravado !"
								Else
									Conout(STR0199)//"O movimento de venda perdida para este item não será gravado !"
								EndIf
								LA701RemVp()
							Endif
					    Endif

						//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
						//³Release 11.5 - Cartao Fidelidade 							    ³
						//³Se a funcionalidade de recarga de saldo em cartao fidelidade     ³
						//³estiver ativa,ao excluir um produto o array aRecSaldo sera limpo.³
						//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					    If lLjcFid
					    	LaFunhDelS()
					    EndIf
					EndIf

					If lIsRecCel //Se for produto "Recarga de Celular"
						//Cancela transacao TEF referente a "Recarga de Celular"
						If Lj7RCStatus()
							Lj7RCStatus(.F.) //Atualiza o status para "Recarga NAO efetuada"
							oTef:FinalTrn(0) //Envia o desfazimento da transacao TEF
						Endif
					EndIf

					If ExistFunc("Lj7CP_OK") .And. Lj7CP_OK() .And. lIsRecCP //Se for produto "Recarga de Cartao Presente" (Gift Card)
						//Cancela transacao TEF referente a "Recarga de Cartao Presente" (Gift Card)
						If Lj7CPGetSt()=="S"
							Lj7CPSetSt(2) //Atualiza o status para "Recarga NAO efetuada"
							oTef:FinalTrn(0) //Envia o desfazimento da transacao TEF
						Endif
					EndIf

					//Atualiza a informacao de Vale presente
					If !Empty(Lj7VPYesNo())

						If Lj7VPIsPrd(aCols[n][nPosProd]) .AND. !IsInCallStack("Lj7PrepDel")

							Lj7VPVdaVP(0) //Indica que ainda nao esta definido se eh vale presente

						Else

							// Somente atualiza se todos estiverem deletados
							For nFor := 1 to Len(aCols)

								If !(aCols[nFor][Len(aCols[nFor])]) .AND. (nFor <> N)
									lTdsDel := .F.
									Exit
								EndIf

							Next nFor

							If lTdsDel
								Lj7VPVdaVP(0) //Indica que ainda nao esta definido se eh vale presente
							EndIf

						EndIf

					EndIf

					If lFtvdVer12

						//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
						//³Se o cliente for Suframa, atualiza o valor do calculo.³
						//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
						If MaFisRet(,"NF_SUFRAMA")
							nAuxSuframa := MaFisRet(,"NF_DESCZF")
							LjVDT_SUFR( 2, nAuxSuframa	)
						EndIf

					EndIf

				EndIf
			Else
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Nao deixar dar um recall no item ja excluido e cancelado na impressora fiscal³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				If !lVAssConc
					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³ Limitacao de 10.000,00 - Legislacao Paulista 	³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					If lExLegSP10 .AND. lExTotalCF
						If nPosEntrega > 0
							If ValType(aCols[n][nPosEntrega]) == "C"
								cEntrega := aCols[n][nPosEntrega]
							EndIf
						EndIf

						If !LjNFFimVd()
							If LJXTpRetira(cEntrega)
								nVlrItemCF := aCols[n][nPosVlItem]
							EndIf
							lRet := Lj950SP10OK(LJXTotalCF() + nVlrItemCF, 2)
						EndIf
					EndIf

					// Validacao de modulos, P.E e Templates
					lRet := Lj7Call003(nPositem)

					If lRet
						If Lj7RCPrdRC(aCols[n][nPosProd]) //Verifica se o produto eh "Recarga de Celular"
							MsgAlert(STR0289) //"Não é permitido restaurar um item de Recarga de Celular!"
							lRet := .F.
						EndIf
					EndIf

					If lRet
						//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
						//³Chama a funcao fiscal para desmarcar a delecao do item         ³
						//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
						If lGE .AND. Ascan(aHeader,{|x| Alltrim(Upper(x[1])) == "LR_GARANT"}) > 0
							nGarant		:= Ascan(aHeader,{|x| Alltrim(Upper(x[2])) == "LR_GARANT"})
							nPosItGar	:= Ascan(aHeader,{|x| Alltrim(Upper(x[2])) == "LR_ITEMGAR"})
							nItemGar 	:= Val(aCols[n][nPosItGar]) //Posicao do Item Garantia
						EndIf

						If lSFinanc .AND. Ascan(aHeader,{|x| Alltrim(Upper(x[2])) == "LR_ITEMCOB"}) > 0
							nPosItSer := Ascan(aHeader,{|x| Alltrim(Upper(x[2])) == "LR_ITEMCOB"})
						EndIf

						If Len(aColsDet) >= n .And. aCols[n][Len(aCols[n])]
							aSB1Ord := SB1->(GetArea())
							If AllTrim(Posicione("SB1", 1, xFilial("SB1") + aCols[n][nPosProd], "B1_TIPO")) == AllTrim(cMvLjTGar)
						    	MsgAlert(STR0331 + CRLF +; //#STR0331->"Produto Garantia Estendida não pode ser restaurado."
						 				 STR0332, STR0056) //#STR0332->"Para isso, é necessário cancelar o item que possui a garantia estendida e informa-lo novamente na venda." ##STR0056->"Atenção"
								lRet := .F.
							ElseIf lSFinanc .AND. AllTrim(Posicione("SB1", 1, xFilial("SB1") + aCols[n][nPosProd], "B1_TIPO")) == AllTrim(cMvLjTSf) .AND.;
								Posicione("MG8", 2, xFilial("MG8") + aCols[n][nPosProd], "MG8_TPXPRD") == "1"

								//Busca posicao do Item Servico
								nItemSer := Val(aCols[n][nPosItSer])

								If nItemSer == 0 .OR. aCols[nItemSer][Len(aHeader)+1]
									MsgAlert(STR0342) //#STR0342->"A venda de um produto tipo serviço financeiro é permitida somente amarrada a um produto com cobertura."
									lRet := .F.
								EndIf
							EndIf
							RestArea(aSB1Ord)
						EndIf

						//Verifica a recuperação da linha do Serviço Financeiro
						If lRet .AND. lSFinanc .AND. ((!Empty( aCols[n][nPosProd] ) .AND. !lFtvdVer12) .OR. (lAtuSaldo .AND. lFtvdVer12)) //Continua a validacao somente se o produto estiver informado
							//Não permite recuperar Servico Financeiro
							If !Empty(aCols[n][nPosItSer]) .And. aCols[n][Len(aHeader)+1]
								MsgAlert(STR0369) //"Não é permitido recuperar Serviço Financeiro vinculado, adicione-o novamente através do produto cobertura!"
								lRet := .F.
							ElseIf aCols[n][Len(aHeader)+1] .And. Posicione("SB1", 1, xFilial("SB1") + aCols[n][nPosProd], "B1_TIPO") ==  cMvLjTSF
								MsgAlert(STR0370) //"Não é permitido recuperar Serviço Financeiro, insira-o novamente!")
								lRet := .F.
							EndIf
						EndIf

						If lRet
							MaFisDel( n, .F. )

							If !lP7VlDev .AND. n > 1 .AND. AllTrim(Posicione("SB1", 1, xFilial("SB1") + aCols[n][nPosProd], "B1_TIPO")) == cMvLjTGar  // Len(aCols) > n
								//Habilita Item Garantia Estendida
								If lGE .AND. !Empty(aCols[n][nGarant])

										oGetVA:GoTo(nItemGar)

										MaFisDel(n, .F.)
										aCols[n, Len(aHeader)+1] := .F.
										aColsDet[n][Len(aColsDet[n])] := .F.

									//Retorna posicao inicial
									oGetVA:GoTo(nBkLine)
								EndIf

								//Habilita Itens Servico Financeiro atrelados
								If lSFinanc .AND. Empty(aCols[n][nPosItSer])
									For nX := 1 To Len(aCols)
										If (nX <> nItemGar .OR. nX <> nBkLine) .AND. aCols[nX][nPosItSer] == aCols[nBkLine][nPosItem] .AND.;
											Posicione("SB1", 1, xFilial("SB1") + aCols[nX][nPosProd], "B1_TIPO") == cMvLjTSf .AND.;
											Posicione("MG8", 2, xFilial("MG8") + aCols[nX][nPosProd], "MG8_TPXPRD") == "1"

											oGetVA:GoTo(nX)

											MaFisDel(n, .F.)
									    	aCols[n, Len(aHeader)+1] := .F.
									    	aColsDet[n][Len(aColsDet[n])] := .F.
									    EndIf
									Next nX
								EndIf

								//Retorna posicao inicial
								oGetVA:GoTo(nBkLine)
							EndIf

							//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
							//³Ajusta o array de detalhes                                     ³
							//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
							If Len( aColsDet ) >= n
								aColsDet[n][Len(aColsDet[n])] := .F.
								Lj7Detalhe(.F.)
							EndIf
						EndIf
					EndIf

					// Soma ao total dos impostos o item que anteriormente estava deletado...
					If cPaisLoc == "BRA"

						If lFtvdVer12
							//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
							//³Se o cliente for Suframa, atualiza o valor do calculo.³
							//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
							If MaFisRet(,"NF_SUFRAMA")
								nAuxSuframa := LjVDSuframa()
								LjVDT_SUFR( 2, nAuxSuframa	)
							EndIf
						EndIf
					ElseIf (lAtuSaldo := Lj7RecalImp(n,5)) .AND. lFtvdVer12
						//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
						//³Acrescenta o valor no SubTotal e Total                         ³
						//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
						nAuxTotal := LJ7T_Subtotal(2) + IIf( MaFisFound("IT", n), MaFisRet(n, "IT_TOTAL") - MaFisRet(n, "IT_FRETE"), aCols[n][nPosVlItem] )
					ElseIf !lFtvdVer12
						//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
						//³Acrescenta o valor no SubTotal e Total                         ³
						//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
						nAuxTotal := LJ7T_Subtotal(2) + IIf( MaFisFound("IT", n), MaFisRet(n, "IT_TOTAL")- MaFisRet(n, "IT_FRETE"), aCols[n][nPosVlItem] )
					EndIf
					//Valida se a margem esta aceitavel.
					If lMargem .AND. lRet
						If Lj701MgV(n,,,aCols[n][nPosVlItem])
							If MsgYesNo(STR0325)//"O produto esta fora da margem de preço cadastrada. Deseja continuar ?"
								If !LjProfile(35)
									//Lj7ValDel(, ,  , ,.T.)
									If Len(aColsDet) >= n
									   aColsDet[n][Len(aColsDet[n])] 	:= .T.
									EndIf
									//aColsDet[n][Len( aHeaderDet )+1]	:= .T.
									//aCols[n][Len( aHeader )+1]	:= .T.
									lRet:= .F.
								EndIf
							Else
								//Lj7ValDel(, ,  , ,.T.)
								If Len(aColsDet) >= n
								   aColsDet[n][Len(aColsDet[n])] 	:= .T.
								EndIf
								//aColsDet[n][Len( aHeaderDet )+1]	:= .T.
								//aCols[n][Len( aHeader )+1]	:= .T.
								lRet:= .F.
							EndIf
						EndIf
					EndIf

				Else
					If !lAutoExec
						MsgAlert(STR0231) // Não é permitido restaurar um item cancelado no modo concomitante!
					Else
						Conout(STR0231) // Não é permitido restaurar um item cancelado no modo concomitante!
					Endif
					lRet := .F.
					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³Validacao de modulos, P.E e Templates ³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					Lj7Call003(nPositem)
				EndIf

				// Recalculo da variavel nAuxTotal
				// Devido Localizado ter um calculo diferente, foi protegido com "==BRA"
				If (lRet .AND. cPaisLoc == "BRA")
					nAuxTotal   := 0
					For nX  := 1 to Len(aColsDet)
						// Verifica de esta deletado
						If aColsDet[nX][Len(aColsDet[nX])]
							Loop
						EndIf
						// Incrementa valor do item a variavel nAuxTotal
						nAuxTotal  += IIf(MaFisFound("IT", nX), MaFisRet(nX, "IT_TOTAL") - MaFisRet(nX, "IT_FRETE"), aCols[nX][nPosVlItem])
					Next nX

					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³Retira quantidade do totalizador de quantidade                  ³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

					For nX := 1 To Len(aColsDet)
						If aColsDet[nX][Len(aColsDet[nX])]
							Loop
						EndIf
						nAuxQuant += aCols[nX][nPosQuant]
					Next nX

					If lFtvdVer12
                        If MaFisRet(,"NF_SUFRAMA")
                            nDescSufr := MaFisRet(,"NF_DESCZF")
                            If Len(aTotais)>6
                                LjVDT_SUFR(2, nDescSufr)
                            EndIf
                        EndIf
					ElseIf ExistFunc("Lj7T_Quant")
						Lj7T_Quant( 2, nAuxQuant )
					EndIf

					Lj7T_Total( 2, nAuxTotal  )

					//incluida a validação abaixo para não somar Lj7T_DescV(2) no subtotal SOMENTE quando MV_LJRGDES = .F.,MV_LJTPCAL = 3
					//e opção de exclusão mantendo valor do desconto da venda ou mantendo o percentual do desconto da venda 					    
					If !lNovRegDesc .AND. cTipoCalc == "3" .AND. (Lj7T_DescP( 2 ) > 0 .OR. Lj7T_DescV( 2 ) > 0) .AND. (nDescRad == 1 .OR. nDescRad == 2) 
						Lj7T_Subtotal( 2, nAuxTotal )
						LjValidPer(nDescRad)
					Else
					//para outros casos CONTINUA com tratamento já existente.
						Lj7T_Subtotal( 2, nAuxTotal + Lj7T_DescV(2) )
					EndIf
					
				Endif

				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Ao desfazer a exclusao de um item de venda,   ³
				//³descartar o movimento de venda perdida        ³
				//³relacionado.					                 ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				If lVendaPerdida
			  		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³Obter numero do item pelo indice da colecao³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		  			LA701RemVp()
				Endif
			EndIf
		EndIf
	EndIf

	If lFtvdVer12
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Chamada da funcao FTVD7003 para Fidelizacao (CRDXFUNE)         ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If ExistFunc("FTVD7003()")
			lRet := FTVD7003(.F.,.F.)
			If ValType( lRet ) <> "L"
				lRet := .T.
			EndIf
		EndIf

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Ponto de Entrada de Templates para validar a delecao do item   ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If ExistTemplate("FTVD7003")
			lRet := ExecTemplate("FTVD7003",.F.,.F.,{lRet, aCols[n][nPositem]})
			If ValType( lRet ) <> "L"
				lRet := .T.
			EndIf
		EndIf
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Ponto de entrada para validar a delecao do item                ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If ExistBlock("FTVD7003")
			lRet := ExecBlock("FTVD7003",.F.,.F.,{lRet, aCols[n][nPositem] })
			If ValType( lRet ) <> "L"
				lRet := .T.
			EndIf
		EndIf
	EndIf

	If (lRet .AND. !Empty( aCols[n][nPosProd] ) .AND. !lFtvdVer12) .OR. (lRet .AND. lAtuSaldo .AND. lFtvdVer12) //Continua a validacao somente se o produto estiver informado
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Atualizo variaveis da tela                   ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ


		//incluida a validação abaixo para não somar Lj7T_DescV(2) no subtotal SOMENTE quando MV_LJRGDES = .F.,MV_LJTPCAL = 3
		//e opção de exclusão mantendo valor do desconto da venda ou mantendo o percentual do desconto da venda 	
		If lDeleted .AND. !lNovRegDesc .AND. cTipoCalc == "3" .AND. (Lj7T_DescP( 2 ) > 0 .OR. Lj7T_DescV( 2 ) > 0) .AND. (nDescRad == 1 .OR. nDescRad == 2) 
			Lj7T_Subtotal( 2, nAuxTotal )
			LjValidPer(nDescRad)
		Else
		//para outros casos CONTINUA a validação já existente.
			Lj7T_Subtotal( 2, nAuxTotal + Lj7T_DescV(2) )
		EndIf
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Caso o Valor Total do Orcamento fique negativo ZERA o desconto ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If aTotais[4,2] < 0
			Lj7T_DescP(2,0)
			Lj7T_DescV(2,0)
		EndIf

		If lAtuImpFis
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Na finalizacao da venda concomitante nao chama a ZeraPgos pois os objetos nao estao instanciados ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If !lEndVendCC .AND. !lAltOrc
				If !lPBMDesc .and. Len(aVidaLink) > 2 .And. aVidaLink[3] <> 1 //para nao remover o desconto do adcionado pelo PBM Funcional Card
					If Len(aColsDet) < n .OR. nPosCodBar = 0
						nPosPBM := aScan(aVidaLink[1][2],{|x| Len(x) > 9 .And. x[10] == n .And. x[2] == AllTrim(aCols[n][nPosProd]) })
					Else
						nPosPBM := aScan(aVidaLink[1][2],{|x| Len(x) > 9 .And. x[10] == n .And. x[2] == AllTrim(aColsDet[n][nPosCodBar]) })
					EndIf
					If nPosPBM > 0
						Lj7ZeraPgtos()
					EndIf	
				Else 
					Lj7ZeraPgtos()
				EndIf
			EndIf
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Atualizo variaveis da tela                                     ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			Lj7T_Total( 2, Lj7T_Subtotal( 2 ) - Lj7T_DescV(2) )

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Ao excluir o item recalcula todos os valores e impostos variaveis    ³
			//³Localizacoes                                                         ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If cPaisLoc <> "BRA"
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Neste local o array ainda não esta setado como deletado, por isso    ³
				//³tem que ajustar ,para calculo correto quando deleta ou recupera item
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

				If Len( aColsDet ) >= n  .AND. !lDeleted
			  		aColsDet[n][Len(aColsDet[n])] := .T.
			  	EndIf

				aTotImpsV := {}
				Lj7T_Subtotal( 2, 0 )
				Lj7T_Total( 2, 0 )

				nAuxTotal   := 0
				nVlrImpDisc := 0
				nY := 0
				For nX  := 1 to Len(aCols)
					If !aCols[nX][Len(aCols[nX])]
						M->LR_DESC := aCols[nX][nPosVlDescP]
						nBKP := n
						n := nX
						lj7VlItem(3,nil,nil,nil,.T.)
						n := nBKP
					EndIf
					If MaFisFound("IT", nX)
						MaFisAlt("IT_DESCONTO", aCols[nX][nPosValDesc], nX)
					EndIf
					If aColsDet[nX][Len(aColsDet[nX])]
						Loop
					EndIf
					If nY == 0
						nY := nX
						MaFisRecal("", nY) //Executa o recalculo de apenas um item qualquer para acertar os valores de impostos
					EndIf
					nAuxTotal  += IIf(MaFisFound("IT", nX), MaFisRet(nX, "IT_TOTAL"), aCols[nX][nPosVlItem])
				Next nX

				If MaFisFound("NF")
					nX:= 1
					While MaFisFound("IT",nX)
						If !MaFisRet( nX, "IT_DELETED" )
							MaFisEndLoad(nX,1)
						EndIf
						nX++
					End
					StaticCall( MATXFIS, MaIt2cab )
				EndIf

				nX := 1
				While MaFisFound("IT",nX)
					//Recalcula os impostos variaveis (Localizacoes), atualiza array "aTotImpsV"
					Lj7RecalImp(nX,1,,,,,,.T.)
					nX++
				End

				Lj7T_Subtotal( 2, nAuxTotal )
				Lj7T_Total( 2, LJ7T_SubTotal(2) )

				cMsg :=	STR0091 + TransForm( Lj7T_ImpsV( "3",2 ), PesqPict( "SLR", "LR_VALIMP1",,nMoedaCor ) ) + Space( 10 ) + ;	// "Total Impostos Incluidos "
				STR0092 + TransForm( Lj7T_ImpsV( "1",2 ), PesqPict( "SLR", "LR_VALIMP1",,nMoedaCor ) )						// "Total Impostos Discriminados"
				Lj7R_Rodape( cMsg )

				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Release 11.5 - Controle de Formularios 								  ³
				//³Apenas se a espécie do formulario escolhido pelo usuário no   	      ³
				//³inicio da venda for FCT-FACTURA,o valor do imposto sera discriminado.  ³
				//³Paises:Chile/Colombia - F1CHI		 								  ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				If lCFolLocR5 .AND. LjGRecFo() > 0
					LjxDadosFo(LjGRecFo(),NIL,@cSigEspFo)
					If Rtrim(cSigEspFo) == "FCT"
						cMsg := STR0092+TransForm(A410Arred(Lj7T_ImpsV("1",2),"L1_VALIMP1",nMoedaCor),PesqPict("SLR","LR_VALIMP1",,nMoedaCor))//"Total Impostos Discriminados"
			   		EndIf
				Else
					cMsg :=	STR0091 + TransForm( Lj7T_ImpsV( "3",2 ), PesqPict( "SLR", "LR_VALIMP1",,nMoedaCor ) ) + Space( 10 ) + ;	// "Total Impostos Incluidos "
					STR0092 + TransForm( Lj7T_ImpsV( "1",2 ), PesqPict( "SLR", "LR_VALIMP1",,nMoedaCor ) )						// "Total Impostos Discriminados"
				EndIf

				Lj7R_Rodape( cMsg )

			EndIf
		EndIf
		
		//Recalcula o Desconto o Total novamente.
		If !lNovRegDesc .AND. cTipoCalc == "3" .AND. (Lj7T_DescP( 2 ) > 0 .OR. Lj7T_DescV( 2 ) > 0) .AND. (nDescRad == 1 .OR. nDescRad == 2) 
			MaFisAlt("NF_DESCTOT",0)
			lRet:= LjValidPer(nDescRad)
		EndIf


	EndIf
EndIf

If lDelMarg
	lP7VlDev    := .T.
	lValidSenha	:= .F.
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Verifica se eh para fazer o controle da variavel lP7VlDev. Vide     ³
//³ comentarios da declaracao no inicio desta funcao                    ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lContrPassou
	lP7VlDev := !lP7VlDev
EndIf

If lRet .AND. FindFunction("Lj7Mv_Desc") .AND. Lj7Mv_Desc() .AND. AliasIndic('MDT')

	oMotivoDes := Lj7GetMot()

 	If (!oMotivoDes == Nil)

 		// Verifica se retornou colecao de motivo com chave "n"
 		oMotivoDes:RmValida(n)

 	EndIf

EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Cria/Altera Log de Recuperacao   ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If	lLog4 .And. lRet .And. !Empty(aCols[n,nPosProd]) ;
	.And. !IsInCallStack("lj7VlItem") .And. Len(aColsDet) > 0
	LJAltLogR(M->LQ_NUM, aCols, n)
EndIf

Return lRet
/*/
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Fun‡…o    ³ Lj7CabOk ³ Autor ³ Vendas Cliente        ³ Data ³ 13/09/02 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descri‡…o ³ Executa as validacoes dos Gets.                            ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ ExpL1 := LJ7CabOk( ExpO1 )                                 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ ExpO1 - Objeto da enchoice                                 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Retorno   ³ ExpL1 - Validou ou nao os campos da enchoice               ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³ Uso      ³ MatA103                                                    ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
/*/
Function Lj7CabOk( oEnchoice )

Local lRet 	:= .T.		//Retorno da funcao
Local lCalcIPI := .T.
Local cTpFrete := "" //Tipo do Frete
//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida
Local cNomeProg	:= Iif(lFtvdVer12,"FATA701","LOJA701")	//Nome da Rotina

Do Case
   Case Empty(M->LQ_CLIENTE) .OR. ;
        Empty(M->LQ_LOJA)    .OR. ;
        Empty(M->LQ_VEND)

        If !lAutoExec
		    Aviso(STR0019, STR0020,{STR0028}) //"Atenção"###"Faltam informar campos obrigatórios no cabeçalho da venda." ### "Ok"
		    oEnchoice:SetFocus()
		Else
			ConOut(STR0020)
			Help( " ", 1, "Help",, STR0020, 1, 0 )
	    EndIf
	    lRet := .F.
   OtherWise
	    If !MaFisFound("NF")
		   lCalcIPI    := Ascan(aPosCpoDet,{|x| Alltrim(Upper(x[1])) == "LR_VALIPI"})	 > 0
			cTpFrete := Lj7TpFrete(M->LQ_CLIENTE,M->LQ_LOJA)
			cTpFrete	:= IIf( Empty(cTpFrete) .And. (M->LQ_TPFRET == "S" .OR. M->LQ_TPFRET == "0"), "S", cTpFrete)

		   MaFisIni( M->LQ_CLIENTE , M->LQ_LOJA , "C" , "S"  , ;
		             NIL           , NIL         , NIL , .F. , ;
		             "SB1"         , cNomeProg   , NIL ,  NIL , ;
		             NIL           , NIL         , NIL ,  NIL , ;
		             NIL           , NIL         , NIL ,  lCalcIPI ,;
		             NIL           , NIL         , NIL ,  NIL , ;
		             NIL				, cTpFrete)

		   IF ExistFunc("LjSatMxFis")
		   		LjSatMxFis()
		   EndIf		             

		   If cPaisLoc == "ARG" .And. SLR->( ColumnPos( "LR_PROVENT" ) ) > 0
			   MaFisLoad("NF_PROVENT",M->LR_PROVENT)
		   EndIf
	    EndIf

	    If cPaisLoc == "BRA" .And. SLQ->(ColumnPos("LQ_RECISS")) > 0 .And. Empty(M->LQ_RECISS)
	    	M->LQ_RECISS := Posicione( "SA1",1,xFilial("SA1")+M->LQ_CLIENTE+M->LQ_LOJA,"A1_RECISS" )
	    EndIf
EndCase

Return lRet

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºFuncao    ³LJ7SetKeysºAutor  ³ Vendas Cliente     º Data ³  02/10/2002 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Carrega/Retira as definicoes de teclado (SetKey)           º±±
±±º          ³                                                            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ ExpL1 - True para Habilitar Setkey                         º±±
±±º          ³         False para Desabilitar SetKey                      º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ Logico - o estado atual dos botoes de atalho.              º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ LOJA701 - Inicializacao/Fechamento do Dialog Principal     º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7SetKeys( lHabilita )
Local  nCount   := 0                // Variavel de loop

Static lLj7SKey := .T.

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Retorna o valor da variavel publica, ja que no LOJA720 ³
//³(LOCXNF) ela eh alterada                               ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If cPaisLoc <> "BRA" .AND. ProcName(1) == "LOJA720"
	bRefresh := {|| oGetVA:oBrowse:Refresh() }	// Bloco de codigo que sera chamado na funcao MafisRef (funcao fiscal)
EndIf

If ValType(lHabilita) == "L"
	lLj7SKey := lHabilita

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Habilita/Desabilita SetKeys                                  ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	For nCount := 1 To Len( aFuncoes )
		Lj7F_Menu( nCount, lHabilita )
	Next nCount
EndIf
Return lLj7SKey

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³Lj7legenda ³ Autor ³ Vendas Cliente       ³ Data ³ 16/09/05 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Legenda da Venda Assistida                                 ³±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±³Uso		 ³ Automacao Comercial										  ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7Legenda()

BrwLegenda(STR0027,STR0007,Lj7CorLege()) 			//"Orcamentos"###"Legenda"

Return .T.

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³Lj7CorLege ³ Autor ³ Vendas Cliente       ³ Data ³ 11/09/12 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Legenda da Venda Assistida                                 ³±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±³Retorno   ³ ExpA1 - Array com as cores da legenda                      ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ Automacao Comercial/Call Center (TMKC010-Perf. do Contato) ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7CorLege()
//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida
Local aLegenda := { {"BR_VERDE",	STR0021},; 	//"Orçamentos em aberto"
					{"BR_VERMELHO",	STR0022},; 	//"Vendas efetuadas"
					{"BR_AMARELO",	STR0023},; 	//"Orcamentos com reservas"
					{"BR_AZUL",		STR0024},; 	//"Pedidos encerrados"
					{"BR_PRETO",	STR0025},; 	//"Orcamentos em aberto vencidos"
					{"BR_MARROM",	STR0026},; 	//"Devoluções pendentes"
					{"BR_BRANCO",	STR0090},; 	//"Transação TEF desfeita"
					{"BR_LARANJA",	STR0129},; 	//"Orcamentos com Pedidos de Venda"
					{"BR_CINZA",	STR0135},; 	//"Orcamentos pagos no FrontLoja"
					{"BR_PINK",		STR0140},; 	//"Orcamentos Cancelados"
					{"BPMSEDT1",	STR0201} } 	//"Vendas Estornadas"		  //// estorno
If lUsaIntFS == NIL
	lUsaIntFS	:= SuperGetMV("MV_LJINTFS",,.F.) .And. LjUpd90Ok(, !IsBlind())
EndIf
If lUsaIntFS
	aAdd(aLegenda,	{"PMSTASK1",STR0262}) 	//"Orcamtos reprovado analise credito"
	aAdd(aLegenda,	{"PMSTASK2",STR0263})	//"Orcamtos mesa de credito"
	aAdd(aLegenda,	{"PMSTASK3",STR0269})	//"Orcamtos mesa de credito"
	aAdd(aLegenda,	{"BPMSTSK1A",STR0264}) 	//"Orcamtos Ped Venda reprov analise cred"
	aAdd(aLegenda,	{"BPMSTSK2A",STR0265}) 	//"Orcamtos Ped Venda mesa de credito"
	aAdd(aLegenda,	{"BPMSTSK3A",STR0270}) 	//"Orcamtos Ped Venda mesa de credito"
	aAdd(aLegenda,	{"BPMSTSK1E",STR0266})	//"Orcamtos reservas reprov analise cred"
	aAdd(aLegenda,	{"BPMSTSK2E",STR0267}) 	//"Orcamtos reservas mesa de credito"
	aAdd(aLegenda,	{"BPMSTSK3E",STR0271})	//"Orcamtos reservas mesa de credito"
EndIf

aAdd(aLegenda,	{"BPMSEDT2"		, STR0441 + STR0372} )	//"NFC-e / NF-e | " + "Canc. com processamento pendente"
aAdd(aLegenda,	{"BR_PRETO_0"	, STR0441 + STR0373} )	//"NFC-e / NF-e | " + "Cancelamento não enviado ao TSS"
aAdd(aLegenda,	{"BR_PRETO_1"	, STR0441 + STR0374} )	//"NFC-e / NF-e | " + "Canc. aguardando autorização do SEFAZ"
aAdd(aLegenda,	{"BR_PRETO_2"	, STR0441 + STR0375} )	//"NFC-e / NF-e | " + "Cancelamento autorizado pelo SEFAZ"
aAdd(aLegenda,	{"BR_PRETO_3"	, STR0441 + STR0376} )	//"NFC-e / NF-e | " + "Cancelamento não autorizado pelo SEFAZ"

If lFtvdVer12
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Ponto de entrada para inclusão de status no orçamento³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If ExistBlock("FTVD70LG")
    	aLegenda:=ExecBlock("FTVD70LG",.F.,.F.,{@aLegenda,"1"})
	Endif

	If FindFunction("P_FTVD7051")
		P_FTVD7051( 1 , @aLegenda )
	ElseIf FindFunction("U_FTVD7051")
		U_FTVD7051( 1 , @aLegenda )
	EndIf

Else

	If FindFunction("P_LJ7051")
		P_LJ7051( 1 , @aLegenda )
	EndIf

	If FindFunction("U_LJ7051")
		U_LJ7051( 1 , @aLegenda )
	EndIf

EndIf

Return aLegenda


/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³LJ7Orcam  ºAutor  ³ Vendas Cliente     º Data ³  21/10/02   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Chama o rdmake para impressao do orcamento                  º±±
±±º          ³                                                            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³Loja701                                                     º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7Orcam()
Local cScrOrc 	:= SuperGetMV("MV_SCRORC")	//Nome do rdmake de impressao de orcamento
Local aRetLeg	:= LJAnalisaLeg(36)
//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida
If !lAutoExec
	If LjNfPafEcf(SM0->M0_CGC) .AND. !lFtvdVer12 .AND. !SL1->L1_IMPNF
		If lPreVenda .AND. LjMPreVend(SM0->M0_CGC)
			LJMsgLeg(aRetLeg)
		Else
			LOJR210()
		EndIf
	Else             
		If ExistBlock("FTVD210") .AND. lFtvdVer12
			FTVD210()
		EndIf

		If LJAnalisaLeg(36)[1] .AND. LjMPreVend(SM0->M0_CGC)
			LJMsgLeg(aRetLeg)
		Else
			If ExistBlock(cScrOrc,,.T.) .OR. ( __lPyme .AND. FindFunction("U_"+cScrOrc)) // Permite a impressão de orçamento para Serie 3
				ExecBlock(cScrOrc,.F.,.F.)
			EndIf
		EndIf
	EndIf
EndIf

Return Nil

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³LJ7ESTOQUEºAutor  ³ Vendas Cliente     º Data ³  23/10/02   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Funcao para consulta do estoque                             º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ Venda Assistida                                            º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function LJ7Estoque()

Local nPosProd		:= aPosCpo[Ascan(aPosCpo,{|x| Alltrim(Upper(x[1])) == "LR_PRODUTO"})][2]	// Posicao da codigo do produto
Local nPosDtLocal  	:= Ascan(aPosCpoDet,{|x| Alltrim(Upper(x[1])) == "LR_LOCAL"})				// Posicao do local (armazem)
Local cProduto 		:= ""																		// Cod. do produto
Local oEstoque																					// Obj. dialog Estoque
Local lContinua     := .T.																		// Define se continua a execucao da funcao
Local xRet																						// Retorno do Ponto de Entrada LJ7045
Local aReaSm0  := SM0->(GetArea())															// Alterado consulta estoque
//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida
If ExistBlock("LJ7045") .AND. !lFtvdVer12
	xRet  := ExecBlock("LJ7045",.F.,.F.)
	If Valtype(xRet) == "L"
		If !xRet
			lContinua  := .F.
		EndIf
	EndIf
EndIf

If ExistBlock("FTVD7045") .AND. lFtvdVer12
	xRet  := ExecBlock("FTVD7045",.F.,.F.)
	If Valtype(xRet) == "L"
		If !xRet
			lContinua  := .F.
		EndIf
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Se usar a consulta de estoque por filial, chama tela de consulta³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lContinua .AND. SuperGetMV("MV_LJESTFL",,.F.) .AND. FindFunction("LJXEstoque()")
	LJXEstoque()
	lContinua  := .F.
Endif

If lContinua
	If !Empty(aCols[n][nPosProd]) .AND. Len(aColsDet) >= n .AND. !aCols[n][Len(aCols[n])]
		cProduto 	:= aCols[n][nPosProd]
		cLocal 		:= aColsDet[n][nPosDtLocal]

		DbSelectArea( "SB1" )
		DbSeek( xFilial() + cProduto )

		DbSelectArea( "SB2" )
		DbSeek( xFilial() + cProduto + cLocal )

		DbSelectArea( "SB0" )
		DbSeek( xFilial() + cProduto )

		DbSelectArea( "SB9" )
		DbSeek( xFilial() + cProduto + cLocal )

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Desabilita as teclas de atalho                                           ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		Lj7SetKeys(.F.)

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Mostra dados do Produto.   ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		DEFINE MSDIALOG oEstoque FROM 10, 16 TO 29, 73.5 TITLE STR0060;  //"Consulta Estoque"
		STYLE nOr( DS_MODALFRAME, WS_DLGFRAME ) OF oDlgVA

		//ÚÄÄÄÄÄÄÄÄ¿
		//³ Dados  ³
		//ÀÄÄÄÄÄÄÄÄÙ
		@	8, 2 TO	43, 187 OF oEstoque PIXEL
		@ 51, 2 TO	70, 187 OF oEstoque PIXEL
		@ 76, 2 TO 135, 187 OF oEstoque PIXEL

		@ 4,    2 SAY STR0061 	            SIZE	56, 7 OF oEstoque PIXEL  // Dados do Produto:
		@ 16,   4 SAY STR0062 				SIZE	21, 7 OF oEstoque PIXEL  // C¢digo
		@ 15,  26 MSGET SB1->B1_COD      	SIZE	49, 9 OF oEstoque PIXEL When .F.
		@ 16,  83 SAY STR0063 			    SIZE	25, 7 OF oEstoque PIXEL  // Unidade
		@ 15, 110 MSGET SB1->B1_UM       	SIZE	14, 9 OF oEstoque PIXEL When .F.
		@ 16, 137 SAY STR0064  				SIZE	18, 7 OF oEstoque PIXEL  // Grupo
		@ 15, 158 MSGET SB1->B1_GRUPO    	SIZE	14, 9 OF oEstoque PIXEL When .F.
		@ 30,   4 SAY STR0065 			    SIZE	32, 7 OF oEstoque PIXEL // Descri‡Æo
		@ 29,  36 MSGET SB1->B1_DESC     	SIZE   130, 9 OF oEstoque PIXEL When .F.
		@ 40, 335 TO 40, 335 OF oEstoque PIXEL
		@ 46,   3 SAY STR0066 + cLocal     SIZE	    60, 7 OF oEstoque PIXEL // "Estoque - Armazém "

		//ÚÄÄÄÄÄÄÄÄ¿
		//³ Saldo  ³
		//ÀÄÄÄÄÄÄÄÄÙ
		@ 57,   4 SAY STR0067	 SIZE 21, 7 OF oEstoque PIXEL  // Inicial
		@ 56,  25 MSGET SB9->B9_QINI Picture PesqPict("SB9","B9_QINI") SIZE 49, 9 OF oEstoque PIXEL When .F.
		@ 57,  89 SAY STR0068 SIZE 18, 7 OF oEstoque PIXEL  // Atual
		@ 56, 107 MSGET SaldoSb2() Picture PesqPict("SB2","B2_QATU") SIZE 49, 9 OF oEstoque PIXEL When .F.

		//ÚÄÄÄÄÄÄÄÄÄÄ¿
		//³ Precos	 ³
		//ÀÄÄÄÄÄÄÄÄÄÄÙ
		@ 71,  3 SAY STR0069            SIZE 53, 7 OF oEstoque PIXEL // Pre‡os de Venda:
		@ 82,  6 SAY "1 -"    SIZE 11, 7 OF oEstoque PIXEL
		@ 93,  6 SAY "2 -"    SIZE 11, 7 OF oEstoque PIXEL
		@ 103, 6 SAY "3 -"    SIZE 11, 7 OF oEstoque PIXEL
		@ 122, 6 SAY "5 -"    SIZE 11, 7 OF oEstoque PIXEL
		@ 83, 93 SAY "6 -"    SIZE 11, 7 OF oEstoque PIXEL
		@ 103,93 SAY "8 -"    SIZE 11, 7 OF oEstoque PIXEL
		@ 93, 93 SAY "7 -"    SIZE 11, 7 OF oEstoque PIXEL
		@ 112,93 SAY "9 -"    SIZE 11, 7 OF oEstoque PIXEL
		@ 112, 6 SAY "4 -"    SIZE 11, 7 OF oEstoque PIXEL

		@ 82,  18 MSGET SB0->B0_PRV1 Picture PesqPict("SB0","B0_PRV1",_PICTURE,1) SIZE 49, 9 OF oEstoque PIXEL When .F.
		@ 91,  18 MSGET SB0->B0_PRV2 Picture PesqPict("SB0","B0_PRV2",_PICTURE,1) SIZE 49, 9 OF oEstoque PIXEL When .F.
		@ 101, 18 MSGET SB0->B0_PRV3 Picture PesqPict("SB0","B0_PRV3",_PICTURE,1) SIZE 49, 9 OF oEstoque PIXEL When .F.
		@ 111, 18 MSGET SB0->B0_PRV4 Picture PesqPict("SB0","B0_PRV4",_PICTURE,1) SIZE 49, 9 OF oEstoque PIXEL When .F.
		@ 121, 18 MSGET SB0->B0_PRV5 Picture PesqPict("SB0","B0_PRV5",_PICTURE,1) SIZE 49, 9 OF oEstoque PIXEL When .F.
		@ 82, 106 MSGET SB0->B0_PRV6 Picture PesqPict("SB0","B0_PRV6",_PICTURE,1) SIZE 49, 9 OF oEstoque PIXEL When .F.
		@ 91, 106 MSGET SB0->B0_PRV7 Picture PesqPict("SB0","B0_PRV7",_PICTURE,1) SIZE 49, 9 OF oEstoque PIXEL When .F.
		@ 101,106 MSGET SB0->B0_PRV8 Picture PesqPict("SB0","B0_PRV8",_PICTURE,1) SIZE 49, 9 OF oEstoque PIXEL When .F.
		@ 111,106 MSGET SB0->B0_PRV9 Picture PesqPict("SB0","B0_PRV9",_PICTURE,1) SIZE 49, 9 OF oEstoque PIXEL When .F.
		DEFINE SBUTTON FROM 010,192 TYPE 1 ACTION oEstoque:End() ENABLE OF oEstoque

		ACTIVATE MSDIALOG oEstoque CENTERED

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Habilita as teclas de atalho                                             ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		Lj7SetKeys(.T.)
	Else
		Aviso( STR0056, STR0070, {STR0028} ) //"Atenção" ### "Selecione um produto na tela de vendas e então chame essa rotina novamente." ### "Ok"
	EndIf
EndIf

RestArea(aReaSm0)

Return Nil

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³LJ7Recebe ºAutor  ³ Vendas Cliente     º Data ³  22/08/03   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Chama a funcao de Recebimentos                             º±±
±±º          ³                                                            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ nExp1 - Opcao selecionada no aRotina                       º±±
±±º          ³ oExp2 - Objeto Listbox com as condicoes de pagamento       º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function LJ7Recebe( nOpc, oTitulo )

Local lRet := .F.									    // Retorno da funcao
Local aRet												// Array com os dados retornados
Local nI												// Controle de loop
Local aHeader											// Dados do cabecalho
Local nVlrTotal											// Valor total
Local cMV_LJRECEB := SuperGetMV("MV_LJRECEB")			// Param. que indica se o recebimento esta ativo
Local cPicE1_Val := PesqPict("SE1", "E1_VALOR", 13)		// Pictures usadas para a edicao dos valores
Local cPicE1_Mul := PesqPict("SE1", "E1_MULTA", 13)		// Pictures usadas para a edicao dos valores
Local cPicE1_Jur := PesqPict("SE1", "E1_JUROS", 13)		// Pictures usadas para a edicao dos valores
Local cPicE1_Des := PesqPict("SE1", "E1_DESCONT", 13)	// Pictures usadas para a edicao dos valores
Local cCodCli	 := Space(TamSx3("A1_COD")[1])			// Variavel para receber o codigo do cliente da rotina de recebimento de titulos
Local cLojaCli	 := Space(TamSx3("A1_LOJA")[1])		// Variavel para receber a loja do cliente da rotina de recebimento de titulos
Local nPosProd   := Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_PRODUTO"}) // Posicao da codigo do produto
Local cMsg       := ""									// Mensagem a ser exibida quando há uma venda iniciada
//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
Local lFtvdVer12	:= LjFTVD()
Local cNomeProg	:= Iif(lFtvdVer12,"FATA701","LOJA701") 	//Nome da Rotina

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Release 11.5 - SmartClient HTML³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If FindFunction ("LjChkHtml")
	If LjChkHtml()
		FwAvisoHtml()
		Return lRet
	EndIf
EndIf
If !lRecebe .AND. nOpc==3

	If Len(aCols) == 1 .And. nPosProd > 0 .And. Empty(aCols[1][aPosCpo[nPosProd][2]])

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Desabilita SetKeys      									 ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		Lj7SetKeys(.F.)
		If Aliasindic("SLV")
			lRecebe	:= .T.
		EndIf
		aRet := LJReceb( @cCodCli, @cLojaCli )
		If aRet[1] > 0

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Atualiza as informacoes do cliente na tela de venda assistida com o cliente que foi       ³
			//³ selecionado os titulos                                                                    ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			M->LQ_CLIENTE	:= cCodCli
			M->LQ_LOJA		:= cLojaCli
			M->LQ_NOMCLI 	:= Posicione("SA1",1,xFilial("SA1")+cCodCli+cLojaCli,"SA1->A1_NOME")

			If cPaisLoc == "ARG" .And. SL1->(FieldPos("L1_ADIC5")) > 0 .And. SLQ->(FieldPos("LQ_ADIC5")) > 0
				M->LQ_ADIC5     := Posicione( "SA1",1,xFilial("SA1")+cCodCli+cLojaCli,"SA1->A1_ADIC5")
				M->LQ_ADIC61    := Posicione( "SA1",1,xFilial("SA1")+cCodCli+cLojaCli,"SA1->A1_ADIC61")
				M->LQ_ADIC62    := Posicione( "SA1",1,xFilial("SA1")+cCodCli+cLojaCli,"SA1->A1_ADIC62")
				M->LQ_ADIC7     := Posicione( "SA1",1,xFilial("SA1")+cCodCli+cLojaCli,"SA1->A1_ADIC7")
			EndIf

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Se o Valor Recebido > 0  Armazena o valor recebido, para permitir a baixa parcial do titulo³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			nVlrTotal := 0
			aTitulo := {}
			For nI := 1 To Len(aRet[2])
				If aRet[2][nI][1]
					AAdd(aTitulo, AClone(aRet[2][nI]))
					nVlrTotal += aRet[2][nI][10]
				EndIf
			Next nI
			lRecebe := .T.
			LJRecHeade(cMV_LJRECEB,, @aHeader)
			oTitulo:SetArray(aTitulo)
			oTitulo:aHeaders := aHeader
			oTitulo:bLine := {|| { aTitulo[oTitulo:nAt][2],;
								   aTitulo[oTitulo:nAt][3],;
								   aTitulo[oTitulo:nAt][4],;
								   aTitulo[oTitulo:nAt][5],;
								   Transform(aTitulo[oTitulo:nAt][ 6],cPicE1_Val),;
								   Transform(aTitulo[oTitulo:nAt][ 7],cPicE1_Mul),;
								   Transform(aTitulo[oTitulo:nAt][ 8],cPicE1_Jur),;
								   Transform(aTitulo[oTitulo:nAt][ 9],cPicE1_Des),;
								   Transform(aTitulo[oTitulo:nAt][10],cPicE1_Val) }}
			oTitulo:lVisible := .T.
			oTitulo:Refresh()
			lRet := .T.
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Atualizar o valor total³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			Lj7T_SubTotal( 2, nVlrTotal )
			Lj7T_Total( 2, Lj7T_Subtotal( 2 ) )

			If lMvLjPdvPa
				Lj7aTitSet(aRet)
			EndIf
		Else
			lRecebe	:= .F.
		EndIf
		
		If lRecebe .AND. !MaFisFound()
			MaFisIni(M->LQ_CLIENTE, M->LQ_LOJA, "C", "S", Nil, Nil, Nil, .F., "SB1", cNomeProg)
			IF ExistFunc("LjSatMxFis")
				LjSatMxFis()
			EndIf			
		EndIf

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Habilita SetKeys      									     ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		Lj7SetKeys(.T.)

	Else

		cMsg := STR0204 + CHR(13)+CHR(10) +; //"Operação Invalida!"
				STR0313 //"Para efetuar o recebimento é necessário finalizar a venda atual."

		If Type("lAutoExec") == "L" .And. lAutoExec
			ConOut(cMsg)
			Help( " ", 1, "Help",, cMsg, 1, 0 )
		Else
			Aviso(STR0015, cMsg, {"Ok"}) //"Atenção"
		EndIf
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Refresh no campo condicao de pagamento na interface         ³
//³do venda assistida visando habilitar ou desabilitar o campo ³
//³caso exista validacao no X3_WHEN do campo LQ_CONDPG.        ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
oCondPg:Refresh()

Return(lRet)

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³LJ7AvalCreºAutor  ³ Vendas Cliente     º Data ³ 15/09/2003  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Faz a avaliacao do credito do cliente                      º±±
±±º          ³                                                            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ LOJA701                                                    º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function LJ7AvalCred(nTipo, aSL1 , aSL2 , aSL4, lTotvsPdv)

Local aRetValue := {.T., "", ""}			// Retorno da avaliação de credito
Local cMsg      := ""							// Mensagem da nao aprovacao do credito
Local nSaldup   := 0							// Total das parcelas com vencto em ddatabase.
Local nSalCli	:= 0							// Armazena o saldo de duplicatas do cliente. A1_SALDUP
Local nLimCred	:= 0						// Armazena o Limite de Credito do cliente
Local nPos      := 0							// Contador do For para aPgtos
Local lAnCred   := .F.							// Boleano utilizado para controle do fluxo logico da rotina
Local cCredLj   := SuperGetMV( "MV_CREDLJ",,"N" )	// Indica se analise de credito deve ser feita por cliente ou loja
Local cCliPad   := SuperGetMV( "MV_CLIPAD",,"000001" )	// Cliente Padrao
Local cLojPad   := SuperGetMV( "MV_LOJAPAD",,"01" )	// Loja do Cliente Padrao
Local cTipoLim  := SuperGetMv("MV_CREDCLI",,"L")//Indica modo de liberacao de credito. C - Cliente; L - Cliente e Loja
Local aAreaSA1	:= SA1->(GetArea())            // Guarda Area SA1
Local cCliloja  := "" 							// Codigo do Cliente na Operacao
Local cLojacli  := ""							// Loja do cliente na Operacao	
Local aFormas   := {}
Local nx        := 0			
Local aparc     := {}

//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida
						
Default nTipo 	:= 0
Default aSL1	:= {}
Default aSL2  	:= {}
Default aSL4  	:= {} 
Default lTotvsPdv := .F.


//Verifica se a Chamada é Provebiente do TotvsPdv
//caso sim, deve setar como .T. para nao exibir msg
If lTotvsPdv
	lAutoExec := .T.
Endif


If Len(aSL1) > 0 .AND. Len(aSL4) > 0
	cCliloja := aSL1[aScan( aSL1, {|x| x[1] == "L1_CLIENTE" } )][2]		
	cLojacli := aSL1[aScan( aSL1, {|x| x[1] == "L1_LOJA" } )][2]
	
	//MONTA ARRAY DE PAGAMENTO NO FORMATO APAGTOS
	For nx:=1 To Len(aSL4)
			
		aadd(aFormas,{stod(aSL4[nx][aScan( aSL4[nx],{|x| x[1] == "L4_DATA"  } )][2]),;
					  	   aSL4[nx][aScan( aSL4[nx],{|x| x[1] == "L4_VALOR" } )][2],;
					  	   aSL4[nx][aScan( aSL4[nx],{|x| x[1] == "L4_FORMA" } )][2],;
					  	   aparc  } )	
	Next nx
			
Else
	cCliloja := M->LQ_CLIENTE
	cLojacli := M->LQ_LOJA
	aFormas  := AClone(aPgtos)
Endif

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Ignorar a analise de credito para cliente "padrao"       ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If cCliloja + cLojacli == cCliPad + cLojPad .OR. Upper(cCredLj) == "N"
	lAnCred	:= .F.
Else
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Ignorar a analise de credito quando pagamento for em dinheiro ³
	//|pois codigo do consumidor permite tal venda                   |
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	For nPos := 1 to Len(aFormas)
		If !IsMoney( aFormas[nPos][_FORMAPGTO] ) .AND. !aFormas[nPos][_FORMAPGTO] $ "VP"
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Tratamento para nao avaliar o credito de clientes que     ³
			//³ estejam pagando a venda com cartao de credito ou debito   ³
			//³ cuja o cadastro da administradora financeira nao esteja   ³
			//³ com com o campo financiamento proprio = "SIM".            ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If Alltrim(aFormas[nPos][_FORMAPGTO]) $ _FORMATEF
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³ Funcao para selecionar a administradora financeira. ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				If !lTotvsPdv .AND. Lj7InfPgtos(nTipo) .AND. Len(aFormas[nPos]) >= 4 .AND. Len(aFormas[nPos][4]) >= 5

					If Posicione("SAE",1,xFilial("SAE")+SubStr(AllTrim(aFormas[nPos][4][5]),1,3),"AE_FINPRO") == "S"
						lAnCred	:= .T. // Analisar o credito
						nSaldup += aFormas[nPos][2]
					EndIf
				Else
					lAnCred := .F.
					aRetValue := {.T., ""} //Retorna como verdadeiro pois cc e cd nao deve ter avaliacao de credito no totvspdv.                  
				EndIf
			Else
				lAnCred	:= .T. // Analisar o credito
				nSaldup += aFormas[nPos][2]
			EndIf
		EndIf
	Next nPos
EndIf

If ExistBlock( "LJ7014" ) .AND. lAnCred .AND. !lFtvdVer12
	lAnCred := ExecBlock("LJ7014" , .F., .F., {cCliloja, cLojacli, nSaldup, aFormas})
EndIf

If ExistBlock( "FTVD7014" ) .AND. lAnCred .AND. lFtvdVer12
	lAnCred := ExecBlock("FTVD7014" , .F., .F., {cCliloja, cLojacli, nSaldup, aFormas})
EndIf

If LJProfile(1) .AND. lAnCred
	aRetValue[1] := MaAvalCred(cCliloja, cLojacli, nSaldup, 1, .F., @aRetValue[2])
	If ( SuperGetMV("MV_LJVCRED",, "1") == "1" )  // Valida se verifica analise de credito pelas regras do sigaloja
		DbSelectArea("SA1")
		DbSetOrder(1)
		If cTipoLim = "C" // Libera credito por cliente
			If DbSeek(xFilial("SA1") + cCliloja)
				nSalCli  := 0
				nLimCred := 0
				While ( !Eof().AND.	SA1->A1_COD == cCliloja)
						If SA1->A1_RISCO == "A"
							Exit
						EndIf
						nSalCli  += SA1->A1_SALDUP
						nLimCred += SA1->A1_LC
						DbSkip()
				EndDo
				If (nSalCli + nSalDup) > nLimCred .AND. SA1->A1_RISCO <> "A"
					aRetValue[1] := .F.
					aRetValue[2] := "01"
				EndIf
			EndIf
		ElseIf DbSeek(xFilial("SA1") + cCliloja +cLojacli) // Libera credito por cliente e loja
			If (SA1->A1_SALDUP + nSalDup) > SA1->A1_LC .AND. SA1->A1_RISCO <> "A"
				aRetValue[1] := .F.
				aRetValue[2] := "01"
			EndIf
		EndIf
	EndIf
	If !Empty(aRetValue[2])
		If aRetValue[2] == "01"
			cMsg := STR0073 //"01-Sem Limite de Crédito"
			aRetValue[3] := STR0073
		ElseIf aRetValue[2] == "04"
			cMsg := STR0074 //"04-Limite de Crédito Vencido"
			aRetValue[3] := STR0074
		Else
			cMsg := STR0075 //"99-Outros"
			aRetValue[3] := STR0075
		EndIf
		If !lAutoExec
			MsgStop(cMsg)
		Else
			ConOut(cMsg)
		EndIf
	EndIf
EndIf

RestArea(aAreaSA1)

Return( aRetValue )

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7XSL1   ºAutor  ³ Vendas Cliente     º Data ³  30/10/03   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Semafaro para fechamento de orcamentos filhos              º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³ Lj7XSL1(cTipo)											  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³	cTipo = Comando, sendo:									  º±±
±±º          ³	"C" - Cria o arquivo                    				  º±±
±±º          ³	"D" - Deleta o arquivoo                    				  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ Resultado do comando                                       º±±
±±º          ³															  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³Loja701                                                     º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7XSL1( cTipo )

Local cExt    := 'LJ7'
Local cImpArq := Space(10)
Local nI      := 0
Local cArq    := SL1->L1_FILIAL+SL1->L1_NUM
Local aDirect
Local lRet    := .T.

cArq := StrTran(Alltrim(cArq)," ","")      // Faz o tratamento no nome do arquivo

If cTipo == "C"
	LJ7ChkSL1Dir()
	cImpArq := STR0076+SL1->L1_NUM						// "Orcamento   :"
	cImpArq += STR0077+DToC(Date())+CRLF				// "Data        :"
	cImpArq += STR0078+Time()+CRLF						// "Hora        :"
	cImpArq += STR0079+Str(SL1->(RECNO()),9)+CRLF		// "Registro SL1:"
	nHdlLJ7 := FCreate(LOG_DIR+cArq+"."+cExt)
	If !Empty(Ferror())
		If !lAutoExec
		    LJMsgRun(STR0080+SL1->L1_NUM+STR0081,,{|| Inkey(2)}) 	//'Orcamento '###' já sendo finalizado por outra estação...'
	    Else
	    	ConOut(STR0080+SL1->L1_NUM+STR0081)
	    	Help( " ", 1, "Help",, STR0080+SL1->L1_NUM+STR0081, 1, 0 )
	    EndIf
	    lRet:=.F.
	    MsUnlockAll()
    Else
		FWrite( nHdlLJ7, cImpArq )
		If ExistBlock("LJ70110")
			ExecBlock( "LJ70110", .F., .F., {cTipo} )
		EndIf
	EndIf
ElseIf cTipo == "D"
	If File(LOG_DIR+cArq+"."+cExt)
		FClose( nHdlLJ7 )
		FErase(LOG_DIR+cArq+"."+cExt)
		If ExistBlock("LJ70110")
			ExecBlock( "LJ70110", .F., .F., {cTipo} )
		EndIf
	EndIf
ElseIf cTipo == "L"  //Limpa
	aDirect := Directory(LOG_DIR+"*.*")
    For nI := 1 to Len(aDirect)
		If File( LOG_DIR+aDirect[nI][1] )
			FErase(LOG_DIR+aDirect[nI][1])
		EndIf
	Next nI
EndIf

Return lRet

/*/
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³ ChkLogDir³ Autor ³ Vendas Cliente        ³ Data ³ 26/07/02 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Verifica a existencia do diretorio de Log                  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso       ³ LOJA701                                                    ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
/*/
Static Function LJ7ChkSL1Dir()

If __lFirstLJ7
	MakeDir("\AUTOCOM")
	MakeDir("\AUTOCOM\LJ7"+cEmpAnt+StrTran(Alltrim(cFilAnt)," ",""))
	__lFirstLJ7 := .F.
EndIf

Return(NIL)


/*/
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³Lj7DetCli ³ Autor ³ Vendas Cliente        ³ Data ³ 07/04/04 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Chama a tela de historico                                  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ cExp1 := Cliente pertencente a Venda                       ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso       ³ LOJA701                                                    ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
/*/
Function Lj7DetCli( cCliente )

Local nPosProduto 	:= aScan( aHeader, { |x| x[2] == "LR_PRODUTO" } )		// Posicao do produto no aHeader
Local nTamA3			:= TamSx3("LQ_NOMVEND")[1] 								// Tamanho do campo LQ_NOMVEN
Local nTamA1			:= TamSx3("LQ_NOMCLI")[1] 								// Tamanho do campo LQ_NOMCLI
Local nTamADIC5		:= 0		// Tamanho do campo LQ_ADIC5
Local nTamADIC61		:= 0 		// Tamanho do campo LQ_ADIC61
Local nTamADIC62		:= 0 		// Tamanho do campo LQ_ADIC62
Local nTamADIC7		:= 0 		// Tamanho do campo LQ_ADIC7
Local aTotaisBkp	:= {} //Backup Totalizadores

Private nFolder 	:= 1 													// Variavel utilizada na funcao TkHistLoj


If cPaisLoc == "ARG" .And. SLQ->(FieldPos("LQ_ADIC5")) > 0 .And. SLQ->(FieldPos("LQ_ADIC61")) > 0
	nTamADIC5		:= TamSx3("LQ_ADIC5")[1] 		// Tamanho do campo LQ_ADIC5
	nTamADIC61		:= TamSx3("LQ_ADIC61")[1] 		// Tamanho do campo LQ_ADIC61
	nTamADIC62		:= TamSx3("LQ_ADIC62")[1] 		// Tamanho do campo LQ_ADIC62
	nTamADIC7		:= TamSx3("LQ_ADIC7")[1] 		// Tamanho do campo LQ_ADIC7
EndIf

If !VerSenha(104) //Permite consulta a Posicao de Cliente
	Help(" ",1,"SEMPERM")
Else
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Grava situacao da venda atual                                            ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	MaFisSave()

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Desabilita as teclas de atalho                                           ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	Lj7SetKeys(.F.)
	
	//Salva Totais
	If Type("aTotais") == "A" 
		aTotaisBkp := aClone(aTotais)
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Chama a tela do historico                                                ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	TkHistLoj( cCliente, IIf( aCols[ n, Len(aCols[n]) ], "", aCols[n,nPosProduto] ), Nil )

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Restaura venda                                                           ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	MaFisRestore()
	
	//Restaura Totais
	If Len(aTotaisBkp) > 0
		aTotais := aClone(aTotaisBkp)
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Atualiza os campos virtuais                                              ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	M->LQ_NOMVEND := PadR(Posicione( "SA3",1,xFilial("SA3")+M->LQ_VEND,"SA3->A3_NOME" ), nTamA3, " " )
	M->LQ_NOMCLI  := PadR(Posicione( "SA1",1,xFilial("SA1")+M->LQ_CLIENTE+M->LQ_LOJA,"SA1->A1_NOME" ), nTamA1, " " )

	If cPaisLoc == "ARG" .And. SL1->(FieldPos("L1_ADIC5")) > 0 .And. SLQ->(FieldPos("LQ_ADIC5")) > 0
		M->LQ_ADIC5   := PadR(Posicione( "SA1",1,xFilial("SA1")+M->LQ_CLIENTE+M->LQ_LOJA,"SA1->A1_ADIC5" ),nTamADIC5," ")
		M->LQ_ADIC61  := PadR(Posicione( "SA1",1,xFilial("SA1")+M->LQ_CLIENTE+M->LQ_LOJA,"SA1->A1_ADIC61" ),nTamADIC61," ")
		M->LQ_ADIC62  := PadR(Posicione( "SA1",1,xFilial("SA1")+M->LQ_CLIENTE+M->LQ_LOJA,"SA1->A1_ADIC62" ),nTamADIC62," ")
		M->LQ_ADIC7   := PadR(Posicione( "SA1",1,xFilial("SA1")+M->LQ_CLIENTE+M->LQ_LOJA,"SA1->A1_ADIC7" ),nTamADIC7," ")
	EndIf
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Habilita as teclas de atalho                                             ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
EndIf

Lj7SetKeys(.T.)

Return Nil

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºFuncao    ³ LOJA701  ºAutor  ³ Vendas Cliente     º Data ³  08/06/05   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDescricao ³ Verifica se os campos das tabelas SL1->SLQ e SL2->SLR      º±±
±±º          ³ criados corretamente                                       º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ cExp1 := Tabela 01 para verificacao de campos              º±±
±±º          ³ cExp2 := Tabela 02 para verificacao de campos              º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ LOJA701                                                    º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function CheckCampos( cTabela1, cTabela2 )

Local nI			:= 0									// Variavel para o laco do FOR NEXT
Local aStru1		:= &(cTabela1)->(dbStruct())			// Estrutura dos campos da primeira tabela
Local aStru2		:= &(cTabela2)->(dbStruct())			// Estrutura dos campos da segunda tabela
Local cMensagem		:= ""									// Campos com irregularidades SL1->SLQ e SL2->SLR
Local cMensagem2	:= ""									// Campos com irregularidades - não existem no SX3

SX3->(DbSetOrder(2))
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Verifica se os campos da Tabela1 existem na Tabela2³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
For nI := 1 To Len(aStru1)
	If AScan(aStru2, {|x| Substr(x[1],4,999) == Substr(aStru1[nI][1],4,999)}) == 0
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Se o campo for de usuario ou de template, mostra a mensagem³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If SX3->(DbSeek(aStru1[nI][1]))
			If SX3->X3_PROPRI $ "UT"
				cMensagem += aStru1[nI][1]+","
			EndIf
		Else
			cMensagem2 += aStru1[nI][1]+","
		EndIf
	EndIf
Next nI
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Verifica se os campos da Tabela2 existem na Tabela1³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
For nI := 1 To Len(aStru2)
	If AScan(aStru1, {|x| Substr(x[1],4,999) == Substr(aStru2[nI][1],4,999)}) == 0
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Se o campo for de usuario ou de template, mostra a mensagem³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If SX3->(DbSeek(aStru2[nI][1]))
			If SX3->X3_PROPRI $ "UT"
				cMensagem += aStru2[nI][1]+","
			EndIf
		Else
			cMensagem2 += aStru2[nI][1]+","
		EndIf
	EndIf
Next nI
If !Empty(cMensagem)
	// "Atenção", "Ao criar um campo na tabela SL1/SL2 é necessário criá-lo também exatamente igual na tabela SLQ/SLR respectivamente. Por favor, revise-os."
	If !lAutoExec
		Aviso(STR0015, STR0094 + CRLF + cMensagem, {"Ok"})
	Else
		ConOut(STR0094 + CRLF + cMensagem)
		Help( " ", 1, "Help",, STR0094 + CRLF + cMensagem, 1, 0 )
	Endif
EndIf
If !Empty(cMensagem2)
	// "Atenção", "Os campos abaixo existem na tabela mas não foram encontrados no dicionário de dados. Por favor, revise-os."
	If !lAutoExec
		Aviso(STR0015, STR0095 + CRLF + cMensagem2, {"Ok"})
	Else
		ConOut(STR0095 + CRLF + cMensagem2)
		Help( " ", 1, "Help",, STR0095 + CRLF + cMensagem2, 1, 0 )
	EndIf
EndIf

Return(NIL)

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7Atalho ºAutor  ³ Vendas Cliente     º Data ³  01/06/05   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Controle das teclas de atalho na toolbar                   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³ Lj7Atalho(ExpN1)   									      º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ ExpN1 - sequencial da tecla de atalho                      º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ Tecla de atalho                                            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ Venda Assistida                                            º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7Atalho( nAtalho )

Local aRet   := {}	// Retorno da funcao

If nAtalho == 5
   aRet  := {5,"Ctrl+E"}
ElseIf nAtalho == 6
   aRet  := {6,"Ctrl+F"}
ElseIf nAtalho == 7
   aRet  := {7,"Ctrl+G"}
ElseIf nAtalho == 8
   aRet  := {8,"Ctrl+H"}
ElseIf nAtalho == 9
   aRet  := {9,"Ctrl+I"}
ElseIf nAtalho == 10
   aRet  := {10,"Ctrl+J"}
ElseIf nAtalho == 11
   aRet  := {11,"Ctrl+K"}
ElseIf nAtalho == 12
   aRet  := {12,"Ctrl+L"}
ElseIf nAtalho == 13
   aRet  := {13,"Ctrl+M"}
ElseIf nAtalho == 14
   aRet  := {14,"Ctrl+N"}
ElseIf nAtalho == 15
   aRet  := {15,"Ctrl+O"}
ElseIf nAtalho == 16
   aRet  := {16,"Ctrl+P"}
ElseIf nAtalho == 17
   aRet  := {17,"Ctrl+Q"}
ElseIf nAtalho == 18
   aRet  := {18,"Ctrl+R"}
ElseIf nAtalho == 19
   aRet  := {19,"Ctrl+S"}
ElseIf nAtalho == 20
   aRet  := {20,"Ctrl+T"}
ElseIf nAtalho == 21
   aRet  := {21,"Ctrl+U"}
ElseIf nAtalho == 22
   aRet  := {22,"Ctrl+V"}
ElseIf nAtalho == 23
   aRet  := {23,"Ctrl+W"}
ElseIf nAtalho == 24
   aRet  := {24,"Ctrl+X"}
EndIf

Return (aRet)

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³Lj7Canc   ºAutor  ³ Vendas Cliente     º Data ³  02/08/05   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Verifica se existe cupom fiscal aberto antes de iniciar a   º±±
±±º          ³operação de venda                                           º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³lExp1 := Habilita/Desabilita pergunta de confirmacao do     º±±
±±º          ³         cancelamento.                                      º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³SIGALOJA - Venda Assistida Concomitante                     º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7Canc( lPergunt )
Local lRet		 := .F.
Local cRetorno	 := " "
Local lCancela	 := .T.
Local lCancelou	:= .F.
//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida
Default lPergunt 	:= .F.

nRet := IFStatus( nHdlECF, '5', @cRetorno )
If nRet = 7
	If !lPergunt      	//Cancelo sem efetuar a pergunta
		If !lAutoExec
			Aviso(STR0100,STR0101,{STR0102}) //"Problemas com o ECF" - "Existe um Cupom Fiscal em aberto e será cancelado!" - "OK"
		Else
		    ConOut(STR0100 + " - " + STR0101)
		EndIf
	    lCancela := .T.
	Else
		//Pergunto antes de cancelar
		If lAutoExec .Or. ( !lAutoExec .And. 1 == MsgYesNo(STR0100))		//"Problemas com o ECF" - "Existe um Cupom Fiscal em aberto, deseja efetuar o cancelamento e abandonar a venda?" - "Sim" "Não"
 		   lCancela := .T.
		Else
 		   lCancela := .F.
		EndIf
	EndIf

	If lCancela
		/*
			Em venda concomitante, para trazer os itens numa queda de energia
			no Registro do PAF, faço copia da SL2 e aqui mando altero a SLX
			subir os itens lançados no Cupom Fiscal
		*/
		If LjNfPafEcf(SM0->M0_CGC) .And. ExistFunc("LjLUpItcc")
			LjLUpItcc()
		EndIf
		
		nRet := IFCancCup( nHdlECF )
		If Lj7VerCmd( nRet )
			lRet := .T.
		Else
			lRet := .F.
		EndIf
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Da um tempo para a impressora fazer a impressao do cancelamento³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		Inkey(8)
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Todos os cancelamentos de cupom irao chamar esta função, portanto abrimos um PE para gravação de logs³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If ExistBlock("L7CAN")
	If !lFtvdVer12
		ExecBlock("L7CAN",.F.,.F.,{lCancela})
	ElseIf lFtvdVer12
		ExecBlock("L7CAN",.F.,.F.,{lCancelou})
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Se foi efetuada a pergunta para o usuário devo tratar se a resposta foi sim ou nao para o programa que chamou³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lPergunt
   lRet := lCancela
EndIf

Return lRet

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³Lj7VldF4   ³ Autor ³ Vendas Cliente       ³ Data ³ 16/09/05 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Validacao da opcao de F4 (Gravacao)                        ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ Automacao Comercial										  ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function LjVldF4()

Local lRet		:= .T.		//Retorno da funcao
Local cCampo	:= ReadVar()

lRet := ((!Empty(cCampo) .AND. SubStr(cCampo,1,5) <> "M->LR") .OR. Empty(cCampo) )

Return( lRet )

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³Lj7VldNCC  ³ Autor ³ Vendas Cliente       ³ Data ³ 20/06/08 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Validacao da NCC no orcamento F4 (Gravacao)                ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±|Parametros³ ExpN1 := Indica que tipo de operacao esta sendo realizada  |±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±|Retorno   ³ Retorna Verdadeiro ou Falso                                |±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ Automacao Comercial										  ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7VldNCC( nOpc, lF5 )
Local lRet 		:= .F.
Local lIntSiac	:= SuperGetMv("MV_SCINTEG", Nil, .F.)	//verifica se a integracao Protheus x SIAC esta ativa
Local lLjNCCOr	:= SuperGetMv("MV_LJNCCOR", Nil, .F.)	//verifica se a NCC sera mantida no orcamento (F4)
Local lIntSynt 	:= SuperGetMV("MV_LJSYNT",,"0") == "1"	// Informa se a integracao Synthesis esta ativa
Local nI        := 0
Local nDifNcc   := 0
Local lAjustNcc := .F.
Local lSelNCC	:= .F.  //Funcionalidade de manter a NCC selecionada 
Local aPrgInfo	:= {} //Versao das rotinas 	
Local lLjNccFi 	:= SuperGetMV("MV_LJNCCFI",,.F.) 		//Permite utilizar NCC de todas as filiais      

Default lF5 := .F.

// VerIfica se foi usada NCC e desconsidera se for orcamento se o usuario desejar.
// Verifica tambem se a NCC sera mantida no orcamento (F4)
If lIntSiac .OR. lIntSynt
	lRet := .T.
ElseIf nNCCUsada > 0
	If lF5 //Venda (F5)                
   		lRet := .T.
        SE1->(dbSetOrder(1)) //E1_FILIAL+E1_PREFIXO+E1_NUM+E1_PARCELA+E1_TIPO
                
        For nI := 1 To Len(aNCCItens)
            If aNCCItens[nI][1] //Ncc selecionada na venda
                //Verifica se saldo da Ncc nao foi alterado por outro processo
				If SE1->(dbSeek(IIf(lLjNccFi, aNCCItens[nI][12], xFilial("SE1")) + aNCCItens[nI][9] + aNCCItens[nI][3] + aNCCItens[nI][10] + aNCCItens[nI][11])) .And. aNCCItens[nI][2] <> SE1->E1_SALDO                                       
                    Alert(STR0437 + SE1->E1_PREFIXO + "/" + SE1->E1_NUM + "/" + SE1->E1_PARCELA + STR0439 + " " +; //#"A Nota de Credito (NCC): " ##" foi utilizada por outro processo enquanto esse atendimento é realizado, reveja as formas de pagamento antes de finalizar a venda."                                                
                    STR0440 + AllTrim(Transform(aNCCItens[nI][2], PesqPict("SE1", "E1_SALDO"))) + ", " + STR0438 + AllTrim(Transform(SE1->E1_SALDO, PesqPict("SE1", "E1_SALDO")))) //#"Saldo inicial: " #"Saldo atual: "
                    
                    lRet      := .F.
                    lAjustNcc := .T. //Flag para ajustar valores Ncc                                        
                    nDifNcc   := aNCCItens[nI][2] - SE1->E1_SALDO
                    nNCCUsada -= nDifNcc //Ajusta valor da Ncc do totalizador
                    aNCCItens[nI][2] -= nDifNcc //Ajusta valor da Ncc do array 
                                        
                    If SE1->E1_SALDO == 0 //Desmarca Ncc pois nao sera mais utilizada                       
                        aNCCItens[nI][1] := .F.  
                    EndIf
                                                                               
                    Exit                    
                EndIf
            EndIf
        Next nI	
	Else 
		//Orcamento (F4)
    	// Verifica se foi usada NCC e desconsidera se for orcamento se o usuario desejar.		//Se usuário não for fiscal, não perguntar sobre NCC.
		If lLjNCCOr
			lSelNCC := .F. //mantém a ncc
			aPrgInfo :=  GetAPOInfo("FRTA060.PRW")
			If Len(aPrgInfo) > 0
				lSelNCC  := aPrgInfo[4] >= Ctod("07/02/2018")
			EndIf
			If lSelNCC
				aPrgInfo :=  GetAPOInfo("FRTA271H.PRW")
				If Len(aPrgInfo) > 0
					lSelNCC  := aPrgInfo[4] >= Ctod("07/02/2018")
				EndIf
			EndIf
			If lSelNCC
				aPrgInfo :=  GetAPOInfo("STBIMPORTSALE.PRW")
				If Len(aPrgInfo) > 0
					lSelNCC  := aPrgInfo[4] >= Ctod("15/02/2018")
				EndIf
			EndIf
			lLjNCCOr := lSelNCC 
		EndIf

    	If !lLjNCCOr
        	lRet := IIF(lAutoExec .OR. (!LjProfile(3)),.T.,MsgYesNo( STR0134 ))	// "A Nota de Credito (NCC) sera desconsiderada ao gravar o orcamento e as parcelas serao recalculadas de acordo com a condicao de pagamento. Deseja continuar?"
            If lRet
            	lAjustNcc := .T. //Flag para ajustar valores Ncc
            	nNCCUsada := 0   //Zera valor da Ncc 
        	EndIf 
        Else 
        	//Este parametro habilitado mantém a NCC no orçamento     
        	lRet := .T.
	    EndIf                  		    	
    EndIf
    
    //Zera informacoes de NCC do Orcamento/Venda
    If lAjustNcc      
    
    	If Empty(M->LQ_CONDPG)
    		M->LQ_CONDPG := SuperGetMV("MV_CONDPAD")
    	EndIf                
        LJ7VldCond( M->LQ_CONDPG , @cDescCondPg, @oDescCondPg, @oPgtos, "" )
        Lj7lAtuCond( .T. )
        Lj7CondPg( 2, M->LQ_CONDPG,, ( ! nNCCUsada > 0 ))
        Lj7AjustaTroco()
            
        If lVisuSint
            oPgtosSint:Refresh()
        EndIf
    
        oPgtos:Refresh()
    EndIf
Else
	lRet := .T.
EndIf

Return lRet

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±³Funcao    ³Lj7PergDes ³ Autor ³ Vendas Cliente       ³ Data ³ 25/04/06 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Valida a tela de desconto, se eh pelo valor, % ou zera     ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701             	    								  ³±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7PergDes()
Local oDescWnd						// Objeto da tela de Desconto
Local oFntDesc						// Objeto que define a fonte
Local oFntDesc1						// Objeto que define a fonte
Local oDescSay1						// Objeto com o label
Local oDescSay2						// Objeto com o label
Local oDescRad						// Objeto radio, para selecionar a opcao desejada
Local nOpcA		:= 1				// Opcao de confirmacao do usuario
Local nValorDesc:= 0				// Recalcula o valor do desconto se manteve a opcao por percentual
Local cBitMap 	:= "PROJETOAP"		// Imagem utilizada na caixa de dialogo
Local lIpiLiq   := .F.				// Controla se existe algum produto com IPI Liquido
Local lOpcao	:= NIL				// Verifica se foi selecionada uma opção valida, caso não seja setada a tela de desconto foi fechada com ALT+F4
Local nX		:= 0				// Contador do For
Local nPosProd 	:= aScan( aHeader, { |x| x[2] == "LR_PRODUTO" } ) // Retorna a posicado do "LR_PRODUTO"
Local cTesAlt	:= ""

While ++nX <= Len(aCols)
	If MaFisRet( nX, "IT_VALIPI" ) > 0
		If !aCols[nX,Len(aHeader)+1] .AND. !Empty(aCols[nX, nPosProd])
			If MaFisRet( nX, "IT_VALIPI" ) > 0
				SF4->( DbSetOrder( 1 ) )
				lIpiLiq := SF4->( DbSeek( xFilial( "SF4" ) + MaFisRet( nX, "IT_TES" ) ) ) .AND. ;
									SF4->F4_TPIPI == "L"
				If lIpiLiq
					cTesAlt += AllTrim(SF4->F4_CODIGO) + "," 
				EndIf
			EndIf
		EndIf
	EndIf
End
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Se tiver apenas 1 produto na aCols e possuir algum produto com IPI, nao exibe a tela. ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If !lIpiLiq .AND. nX > 2

	DEFINE FONT oFntDesc  NAME "Ms Sans Serif" BOLD
	DEFINE FONT oFntDesc1 NAME "Arial" SIZE 15, 20 BOLD

	DEFINE MSDIALOG oDescWnd TITLE STR0054 FROM 10, 10 TO 130, 360 OF GetWndDEFAULT() PIXEL STYLE DS_MODALFRAME	//"Desconto"
	@ 0 , 0 BITMAP oBmp RESNAME cBitMap oF oDescWnd SIZE 200,488 NOBORDER WHEN .F. PIXEL

	@ 05, 07 SAY oDescSay1 VAR STR0106 SIZE 200, 10 PIXEL OF oDescWnd Font oFntDesc		// "Foi detectado uma alteração no desconto do Valor Total."
	@ 20, 07 SAY oDescSay2 VAR STR0107 SIZE 099, 10 PIXEL OF oDescWnd Font oFntDesc		// "Você deseja:"

	@ 30, 07 RADIO	oDescRad VAR nDescRad 3D SIZE 99, 10 PROMPT STR0108, ;	// "Manter o Valor do Desconto?"
					STR0109, STR0110 OF oDescWnd PIXEL		// "Manter a Porcentagem do Desconto?" | "Zerar o valor e a porcentagem?"

	DEFINE SBUTTON FROM 35, 135 TYPE 1 ACTION ( nOpcA := 1, IIF(Lj7ValidDsc(nDescRad),oDescWnd:End(),NIL) , lOpcao := .T. ) ENABLE PIXEL OF oDescWnd

	oDescWnd:LESCCLOSE := .F.

	ACTIVATE DIALOG oDescWnd CENTERED
Else
	cTesAlt := Substr(cTesAlt,1,Len(cTesAlt)-1)
	
	LjGrvLog( NIL, "A(s) TES utilizada(s) constante(s) na tabela SF4 [Tipo de Entrada e Saída] está(ão)"+;
					" com o campo F4_TPIPI preenchido com 'L' e isso "+;
					" faz com que o desconto seja zerado. Caso possível e deseja manter o desconto "+;
					" altere a configuração da TES usada no Produto."+;
					"Código(s) da(s) TES que precisa(m) ser alterada(s):"+cTesAlt)
	Lj7ZeraDesc()
EndIf

If !(ValType(lOpcao) == "L")	// Caso a variável não tenha sido setada significa que nenhuma opção válida e o desconto deve ser anulado
	Lj7ZeraDesc()
EndIf

Return Nil


//--------------------------------------------------------
/*/{Protheus.doc} Lj7ValidDsc()
rotina desenvolvida para validar se o percentual máximo do caixa excede quando exclui um item e seleciona a opção de manter valor do desconto              
@author  caio.okamoto
@version P12.17
@since   12/12/2018
@return  lRet                                                                     
/*/
//--------------------------------------------------------
Static Function Lj7ValidDsc(nOpcDesc )
Local lRet    		:= .T.   //retorno da função. 
Local nPosVlItem 	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VLRITEM"})][2]// Posicao do Valor do item
Local nValDesc		:= 0 	//valor do desconto na venda recalculado
Local aDesc 		:= {}	//array para enviar como parametro o valor e o tipo de desconto 
Default nOpcDesc 	:= 1	//opção de cancelamento 1= manter  valor do desconto da venda, 2= manter percentual do desconto da venda, 3=zerar o desconto da venda.

If nOpcDesc  == 1
	//subtrai o valor do item  a ser excluído do subtotal para calcular se o percentual excede o máximo permitido para o caixa. 
	nValDesc := ( 100 * Lj7T_DescV(2) ) / (LJ7T_SubTotal(2) - aCols[n][nPosVlItem])
	aDesc := {"P",nValDesc}
	If !LjProfile(11, Nil, aDesc, nValDesc, Lj7T_DescV(2))
		lRet := .F.
	EndIf
EndIf

If lRet 
	LjValidPer(nOpcDesc)
EndIf

Return lRet


/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³LJ7CONSEL ºAutor  ³ Vendas Cliente     º Data ³  06/11/06   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Consulta de cheque eletrotico.                              º±±
±±º          ³                                                            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ ExpN1 := Indica que tipo de operacao esta sendo realizada  º±±
±±º          ³ ExpC1 := Retorna o conteudo do paramentro MV_TEFGRT        º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ Returna Verdadeiro ou Falso                                º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ LOJA701                                                    º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Static Function LJ7CONSEL( nOpc, cTefGrt )
Local lRet := .F.								// Variavel de retorno da funcao.

If nOpc <> 2 .AND. cTefGrt <> "S" .AND. lUsaTef
	Do Case
		Case cTipTef == TEF_SEMCLIENT_DEDICADO
			LOJA010T("C")
			lRet := .T.
		Case cTipTef == TEF_COMCLIENT_DEDICADO
			LOJA012T()
			lRet := .T.
	EndCase
Else
	// "Atenção", "Para utilizar esta função, configurar o parâmetro MV_TEFGRT diferente 'S',
	// ser um usuário TEF e estar na tela de atendimento. {OK}
	If !lAutoExec
		Aviso(STR0015, STR0116, {STR0102})
	Else
		ConOut(STR0116)
	EndIF
EndIf

Return( lRet )
/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7AtuPgtoºAutor  ³ Vendas Cliente     º Data ³  16/04/07   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Atualizacao da forma de pagamento                           º±±
±±º          ³                                                            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ LOJA701                                                    º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function Lj7AtuPgto( cAlterCond )

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Se for lAlterOrc esta com a opção de alteracao de orc    ³
//³ entao a função de Lj7AtuPgto nao e chamada              ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If !lAlterOrc
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Se cAlterCond não foi preenchida, a Cond.Pgto nao foi alterada, portanto nao deve ser validada³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	
	If !Empty(M->LQ_CONDPG) .And. cAlterCond <>  M->LQ_CONDPG .AND. !Empty(cAlterCond) //Quando M->LQ_CONDPG estiver em branco "", se faz desnecessaria a validação	
		LJ7VldCond(M->LQ_CONDPG,@cDescCondPg,@oDescCondPg,@oPgtos, @cAlterCond)
	EndIf

	If !lAutoExec
		If lVisuSint
			oPgtosSint:Refresh()
		EndIf

		oPgtos:Refresh()
	Endif

EndIf

Return .T.

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºFuncao    ³Lj7VerifVeºAutor  ³ Vendas Cliente     º Data ³  27/09/06   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDescricao ³ Verifica se a versao esta compativel para ser utilizada    º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ LOJA701                                                    º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function Lj7VerifVer()
Local lRet    := .T.       // Retorno da funcao
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Valida se a versao do fonte contempla o tratamento do frete ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If FindFunction("LjxVerFret") .AND. LjxVerFret() >= 20060927
	If FindFunction("Lj7VerFret") .AND. Lj7VerFret() >= 20060927
		lRet  := .T.
	Else
	    lRet  := .F.
	    If !lAutoExec
			Final(STR0120) 		//Atualizar LOJA701C E LOJXFUNC !!!
		Else
			ConOut(STR0237 + STR0120)		// "Lj7VerifVer - "
			Help( " ", 1, "Help",, STR0237 + STR0120, 1, 0 )
		EndIf
	EndIf
EndIf

Return (lRet)

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºFuncao    ³LjValidPerºAutor  ³ Vendas Cliente     º Data ³  14/09/07   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDescricao ³ Realiza a validacao para desconto no aCols                 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ LOJA701                                                    º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function LjValidPer(nOpcDesc)
Local aDesc 		:= {}				// Array com as informacoes de desconto
Local lRet 			:= .F.				// Retorno da funcao
Local nValorDesc 	:= 0				// Valor de desconto

Default nOpcDesc 		:= 1					// Opcao escolhida

Do Case
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Mantem o valor do desconto³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	Case nOpcDesc == 1
		nValorDesc := ( 100 * Lj7T_DescV(2) ) / LJ7T_SubTotal(2)
		aDesc := {"P",nValorDesc}

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Verifica permissao para desconto³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		MaFisAlt("NF_DESCTOT",0)
		If LjProfile(11, Nil, aDesc, nValorDesc, Lj7T_DescV(2))
			Lj7T_DescP( 2, nValorDesc )
			Lj7T_Total( 2, LJ7T_SubTotal(2) - Lj7T_DescV(2) )
			nValorDesc	:= 0
			lRet := .T.
		EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Mantem o percentual do desconto³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

	Case nOpcDesc == 2
		nValorDesc := ( LJ7T_SubTotal(2) * Lj7T_DescP(2) ) / 100
		aDesc := {"V",nValorDesc}

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Verifica permissao para desconto³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

		If LjProfile(11, Nil, aDesc, Lj7T_DescP(2), nValorDesc)
			Lj7T_DescV( 2, nValorDesc )
			Lj7T_Total( 2, LJ7T_SubTotal(2) - nValorDesc )
			nValorDesc	:= 0
			lRet := .T.
		EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Zera o desconto no total³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	Case nOpcDesc == 3
		Lj7T_DescP	( 2,0 )
		Lj7T_DescV	( 2,0 )
		Lj7T_Total	( 2, LJ7T_SubTotal(2) )
		lRet := .T.
EndCase

Return lRet
/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³LjDocSeq  ºAutor  ³ Vendas Clientes    º Data ³ 09/11/2007  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Funcao para verificar a integridade do numero sequencial de º±±
±±º          ³notas fiscais, armazenado no MV_DOCSEQ.                     º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³Generico                                                    º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function LjDocSeq()
Local aArea		:= GetArea()				// Armazena o posicionamento atual
Local aAlias	:= {"SD1","SD2","SD3"}		// Tabelas que utilizam controle de sequencia de documentos
Local aAreaTmp	:= {}						// Armazenamento temporario das areas utilizadas
Local cBusca	:= ""						// String para busca pelo ultimo sequencial
Local lRet		:= .T.						// Retorno da funcao
Local cMax		:= ""						// Maior documento encontrado entre as tabelas
Local cDoc		:= ""						// Maior documento encontrado para cada tabela
Local nX		:= 0						// Auxiliar de loop
Local nTamSeq	:= 0						// Tamanho do campo de controle de sequencia

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Se o usuario utiliza numeracao especifica, utilizando o ponto³
//³de entrada xProxNum, nao faz validacao                       ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If ExistBlock("XPROXNUM")
	RestArea(aArea)
	Return .T.
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Le o tamanho dos campos de sequencial e monta a string      ³
//³com este tamanho para busca pelo ultimo sequencial utilizado³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
nTamSeq	:= TamSx3("D3_NUMSEQ")[1]
cBusca := Replicate("z",nTamSeq)

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Le o maior numero sequencial existente entre os documentos³
//³de entrada (SD1), saida (SD2) e movimentacao de materiais ³
//³(SD3)                                                     ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
For nX := 1 to Len(aAlias)

	DbSelectArea(aAlias[nX])
	aAreaTmp := GetArea()
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Ordem do DocSeq nas tabelas SD1, SD2 e SD3³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	DbSetOrder(4)
	DbSeek(xFilial(aAlias[nX])+cBusca,.T.)
	DbSkip(-1)

	If &(PrefixoCPO(aAlias[nX]) + "_FILIAL") == xFilial(aAlias[nX])
		cDoc := &(PrefixoCPO(aAlias[nX]) + "_NUMSEQ")
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Armazena o maior sequencial entre as tres tabelas³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If cDoc > cMax
		cMax := cDoc
	EndIf

	RestArea(aAreaTmp)

Next nX

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Obtem o proximo numero a partir do MV_DOCSEQ³
//³Nao utilizar SuperGetMV, quando ExecAuto nao³
//³atualiza o valor do param MV_DOCSEQ		   ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
cProx := Soma1(PadR(GetMV( "MV_DOCSEQ",,"" ),nTamSeq),,,.T.)

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Verifica se o MV_DOCSEQ esta gravado corretamente³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If cMax >= cProx
	lRet := .F.
	If !lAutoExec
		MsgStop(STR0127 + cMax + STR0128 ,STR0238)	//"Problema no conteudo do parametro MV_DOCSEQ. O valor correto deveria ser: "###". A venda assistida não poderá ser executada até sua correção.", "MV_DOCSEQ"
	Else
		ConOut(STR0127 + cMax + STR0128 )	//"Problema no conteudo do parametro MV_DOCSEQ. O valor correto deveria ser: "###". A venda assistida não poderá ser executada até sua correção."
		Help( " ", 1, "Help",, STR0127 + cMax + STR0128, 1, 0 )
	EndIf
EndIf

RestArea(aArea)

Return lRet

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7DefLeg ºAutor  ³Vendas Clientes     º Data ³  24/01/08   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Define as cores das Legendas                               º±±
±±º          ³                                                            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ LOJA701                                                    º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function Lj7DefLeg()
Local aCores	:= {}																			//Array com as validacoes e cores da Legenda
Local lLjPedVe	:= SuperGetMV("MV_LJPEDVE", NIL, .F.)											//Verifica se utiliza emissao de Pedidos de Venda
Local lPosPed	:= SL1->(ColumnPos("L1_PEDRES")) > 0 .AND. SLQ->(ColumnPos("LQ_PEDRES")) > 0	//Verifica se os campos L1_PEDRES e LQ_PEDRES estao criados
Local cStatAp	:= "" //Regra para verificação da Orçamento Liberado: sem execução da analise de credito (branco) ou com analise aprovada
Local lSFinanc	:= AliasIndic("MG8") .AND. SuperGetMV("MV_LJCSF",,.F.)							// Valida implementação do servico financeiro
Local lLstPre	:= SuperGetMV("MV_LJLSPRE",,.F.)
Local lIntegHtl := SuperGetMv("MV_INTHTL",, .F.) .And. FWHasEAI("LOJA701",, .T., .T.) //Integracao via Mensagem Unica - Hotelaria
//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
Local lEmitNfce	:= LjEmitNFCe()// Sinaliza se utiliza NFC-e
Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida

If lUsaIntFS == NIL
	lUsaIntFS	:= SuperGetMV("MV_LJINTFS",,.F.) .And. LjUpd90Ok(, !IsBlind())
EndIf
If lUsaIntFS
	cStatAp := ' .AND. (FieldPos("L1_IFSANST") = 0 .OR. Empty(L1_IFSANST) .OR. L1_IFSANST == "1") '
EndIf

Aadd(aCores, {'!Empty(L1_DOC) .AND. !Empty(L1_SERIE) .AND. AllTrim(L1_STATUS) == "T"  .AND. (FieldPos("L1_STATUES") = 0 .Or. Empty(L1_STATUES))'																					,"BR_BRANCO"	})	//"Transação TEF desfeita"

If lIntegHtl //Tratamento de legenda hotelaria	
	Aadd(aCores, {'L1_SITUA == "OK" .AND. !(L1_STATUS $ "D|F") .AND. (FieldPos("L1_STATUES") = 0 .Or. Empty(L1_STATUES))', "BR_VERMELHO"})	//"Vendas efetuadas"
ElseIf lEmitNFCe .Or. lIsPafNfce
	Aadd(aCores, {'!Empty(L1_DOC) .AND. !Empty(L1_SERIE) .AND. L1_STORC <> "A" .AND. !(L1_SITUA $ "X0|X1|X2|X3") .AND. !(L1_STATUS $ "D|F") .AND. (FieldPos("L1_STATUES") = 0 .OR. Empty(L1_STATUES))'							,"BR_VERMELHO"	})	//"Vendas efetuadas"
	Aadd(aCores, {'!Empty(L1_DOC) .AND. L1_TPORC == "E" .AND. L1_SITUA == "RX" .AND. L1_STORC == "A"'																															, "BPMSEDT2"	})	//"Cancelamento com processamento pendente"
Else
	Aadd(aCores, {'!Empty(L1_DOC) .AND. !Empty(L1_SERIE) .AND. L1_STATUS <> "D" .AND. L1_STATUS <> "F"   .AND. (FieldPos("L1_STATUES") = 0 .Or. Empty(L1_STATUES))'  																	,"BR_VERMELHO"	})	//"Vendas efetuadas"
EndIf

//Cancelamento de NFC-e ou NF-e por etapa
Aadd(aCores, {'!Empty(L1_DOC) .AND. (L1_TPORC == "E" .OR. L1_IMPNF) .AND. L1_SITUA $ "X0|RY"'	, "BR_PRETO_0"	})	//"Cancelamento não enviado ao TSS"
Aadd(aCores, {'!Empty(L1_DOC) .AND. (L1_TPORC == "E" .OR. L1_IMPNF) .AND. L1_SITUA == "X1"'		, "BR_PRETO_1"	})	//"Cancelamento aguardando autorização do SEFAZ"
Aadd(aCores, {'!Empty(L1_DOC) .AND. (L1_TPORC == "E" .OR. L1_IMPNF) .AND. L1_SITUA == "X2"'		, "BR_PRETO_2"	})	//"Cancelamento autorizado pela SEFAZ"
Aadd(aCores, {'!Empty(L1_DOC) .AND. (L1_TPORC == "E" .OR. L1_IMPNF) .AND. L1_SITUA == "X3"'		, "BR_PRETO_3"	})	//"Cancelamento não autorizado pela SEFAZ"

If lSFinanc
	Aadd(aCores, {'!Empty(L1_DOCPED) .AND. !Empty(L1_SERPED) .AND. L1_SITUA == "OK" .AND. L1_STATUS <> "D" .AND. L1_STATUS <> "F" .AND. (FieldPos("L1_STATUES") = 0 .Or. Empty(L1_STATUES))', "BR_VERMELHO"	})	//"Vendas efetuadas"
EndIf

If lMvLjPdvPa .Or. lLstPre
	//Condicao especifica para PDV PAF quando existe apenas item de entrega na venda
	Aadd(aCores, {'!Empty(L1_DOCPED) .AND. !Empty(L1_RESERVA) .AND. Empty(L1_DOC) .AND. (!Empty(L1_SERIE) .Or. !Empty(L1_SUBSERI)) .AND. L1_STATUS <> "D" .AND. L1_STATUS <> "F" .AND. (FieldPos("L1_STATUES") = 0 .Or. Empty(L1_STATUES))'  																	,"BR_VERMELHO"	})	//"Vendas efetuadas"
EndIf

Aadd(aCores, {'ColumnPos("L1_STATUES")> 0 .and. !Empty(L1_STATUES)',"BPMSEDT1"     })    //"Vendas estornadas"  -   estorno
Aadd(aCores, {'Empty(L1_DOC) .AND. Empty(L1_DOCPED) .AND. Empty(L1_RESERVA) .AND. L1_STATUS <> "D" .AND. IIf(SL1->(FieldPos("L1_STORC")) >0, L1_STORC <> "C", .T.) .AND. (FieldPos("L1_STATUES") = 0 .Or. Empty(L1_STATUES)) .AND. L1_TIPO == "P"' + cStatAp	,"BR_VERMELHO"		})	//"Vendas efetuadas" - Somente para vendas que os produtos da L2 sejam GE ou SF

If lIntegHtl //Tratamento de legenda hotelaria
	Aadd(aCores, {'SL1->L1_SITUA <> "OK" .AND. Empty(L1_RESERVA) .AND. dDataBase <=L1_DTLIM', "BR_VERDE" })	//"Orçamentos em aberto"
Else
	Aadd(aCores, {'Empty(L1_DOC) .AND. Empty(L1_RESERVA) .AND. dDataBase<=L1_DTLIM .AND. L1_STATUS <> "D" .AND. IIf(SL1->(FieldPos("L1_STORC")) >0, L1_STORC <> "C", .T.)   .AND. (FieldPos("L1_STATUES") = 0 .Or. Empty(L1_STATUES))' + cStatAp	,"BR_VERDE"		})	//"Orçamentos em aberto"
EndIf

If lLjPedVe .AND. lPosPed
	Aadd(aCores, {'Empty(L1_DOC) .AND. !Empty(L1_RESERVA) .AND. Empty(L1_DOCPED) .AND. L1_STATUS <> "D" .AND. Empty(L1_PEDRES)' + cStatAp								,"BR_AMARELO"	})	//"Orcamentos com reservas"
	Aadd(aCores, {'Empty(L1_DOC) .AND. !Empty(L1_RESERVA) .AND. Empty(L1_DOCPED) .AND. L1_STATUS <> "D" .AND. !Empty(L1_PEDRES)' + cStatAp   							,"BR_LARANJA"	})	//"Orcamentos com Pedidos de Venda"
Else
	Aadd(aCores, {'Empty(L1_DOC) .AND. !Empty(L1_RESERVA) .AND. Empty(L1_DOCPED) .AND. L1_STATUS <> "D"' +cStatAp														,"BR_AMARELO"	})	//"Orcamentos com reservas"
EndIf

Aadd(aCores, {'Empty(L1_DOC) .AND.  Empty(L1_RESERVA) .AND. dDataBase>L1_DTLIM  .AND. L1_STATUS<>"D" .AND. IIf(SL1->(FieldPos("L1_STORC")) > 0 , L1_STORC <> "C" , .T.)',"BR_PRETO"		})	//"Orcamentos em aberto vencidos"
Aadd(aCores, {'Empty(L1_DOC) .AND. L1_TIPO=="P"       .AND. !Empty(L1_DOCPED)   .AND. L1_STATUS<>"D"  .AND. (FieldPos("L1_STATUES") = 0 .Or. Empty(L1_STATUES))'						   											,"BR_AZUL"		})	//"Pedidos encerrados"
Aadd(aCores, {'L1_STATUS="D"'																												   							,"BR_MARROM"	})	//"Devoluções pendentes"
Aadd(aCores, {'Empty(L1_DOC) .AND. SL1->(FieldPos("L1_STORC")) > 0 .AND. L1_STORC == "C"'																				,"BR_PINK" 		})	//"Orçamentos Cancelados"


If SL1->(FieldPos("L1_NUMFRT")) > 0
	Aadd(aCores, {'L1_STATUS = "F" .AND. L1_SITUA = "FR" .AND. !Empty(L1_NUMFRT)   .AND. (FieldPos("L1_STATUES") = 0 .Or. Empty(L1_STATUES))'																						,"BR_CINZA"		})	//"Orcamnetos pagos no FrontLoja"
	Aadd(aCores, {'(!Empty(L1_DOC) .OR. !Empty(L1_DOCPED)) .AND. L1_STATUS = "F" .AND. Empty(L1_NUMFRT) .AND. !Empty(L1_NUMORIG)'										,"BR_AZUL"		})	//"Pedidos encerrados"
EndIf

If lUsaIntFS

	Aadd(aCores, {'Empty(L1_DOC) .AND. Empty(L1_RESERVA) .AND. dDataBase<=L1_DTLIM .AND. L1_STATUS <> "D" .AND. IIf(SL1->(FieldPos("L1_STORC")) >0, L1_STORC <> "C", .T.)   .AND. (FieldPos("L1_STATUES") = 0 .Or. Empty(L1_STATUES))' + ' .AND. ( L1_IFSANST == "0") '	,"PMSTASK1"		})	//"Orçamentos reprovado analise de credito"
	Aadd(aCores, {'Empty(L1_DOC) .AND. Empty(L1_RESERVA) .AND. dDataBase<=L1_DTLIM .AND. L1_STATUS <> "D" .AND. IIf(SL1->(FieldPos("L1_STORC")) >0, L1_STORC <> "C", .T.)   .AND. (FieldPos("L1_STATUES") = 0 .Or. Empty(L1_STATUES))' + ' .AND. ( L1_IFSANST == "2") '	,"PMSTASK2"		})	//"Orçamentos mesa de credito
	Aadd(aCores, {'Empty(L1_DOC) .AND. Empty(L1_RESERVA) .AND. dDataBase<=L1_DTLIM .AND. L1_STATUS <> "D" .AND. IIf(SL1->(FieldPos("L1_STORC")) >0, L1_STORC <> "C", .T.)   .AND. (FieldPos("L1_STATUES") = 0 .Or. Empty(L1_STATUES))' + ' .AND. ( L1_IFSANST == "9") '	,"PMSTASK3"		})	//"Orçamentos sem analise de credito/off-line


	If lLjPedVe .AND. lPosPed
		Aadd(aCores, {'Empty(L1_DOC) .AND. !Empty(L1_RESERVA) .AND. Empty(L1_DOCPED) .AND. L1_STATUS <> "D" .AND. Empty(L1_PEDRES)' + ' .AND. ( L1_IFSANST == "0") '								,"BPMSTSK1E"	})	//"Orcamtos reservas - Reprovado anal. credito"
		Aadd(aCores, {'Empty(L1_DOC) .AND. !Empty(L1_RESERVA) .AND. Empty(L1_DOCPED) .AND. L1_STATUS <> "D" .AND. Empty(L1_PEDRES)' + ' .AND. ( L1_IFSANST == "2") '								,"BPMSTSK2E"	})	//"Orcamtos reservas - Mesa de credito "
		Aadd(aCores, {'Empty(L1_DOC) .AND. !Empty(L1_RESERVA) .AND. Empty(L1_DOCPED) .AND. L1_STATUS <> "D" .AND. Empty(L1_PEDRES)' + ' .AND. ( L1_IFSANST == "9") '								,"BPMSTSK3E"	})	//"Orcamtos reservas - sem analise "

		Aadd(aCores, {'Empty(L1_DOC) .AND. !Empty(L1_RESERVA) .AND. Empty(L1_DOCPED) .AND. L1_STATUS <> "D" .AND. !Empty(L1_PEDRES)' + ' .AND. ( L1_IFSANST == "0") '  							,"BPMSTSK1A"	})	//"Orcamtos Ped Venda - reprovado analise de credit0"
		Aadd(aCores, {'Empty(L1_DOC) .AND. !Empty(L1_RESERVA) .AND. Empty(L1_DOCPED) .AND. L1_STATUS <> "D" .AND. !Empty(L1_PEDRES)' + ' .AND. ( L1_IFSANST == "2") '  							,"BPMSTSK2A"	})	//"Orcamtos Ped Venda - Mesa de credito"
		Aadd(aCores, {'Empty(L1_DOC) .AND. !Empty(L1_RESERVA) .AND. Empty(L1_DOCPED) .AND. L1_STATUS <> "D" .AND. !Empty(L1_PEDRES)' + ' .AND. ( L1_IFSANST == "9") '  							,"BPMSTSK3A"	})	//"Orcamtos Ped Venda - sem analise"


	Else
		Aadd(aCores, {'Empty(L1_DOC) .AND. !Empty(L1_RESERVA) .AND. Empty(L1_DOCPED) .AND. L1_STATUS <> "D"' +' .AND. ( L1_IFSANST == "0") '														,"BPMSTSK1E"	})	//"Orcamtos reservas - Reprov analise credito"
		Aadd(aCores, {'Empty(L1_DOC) .AND. !Empty(L1_RESERVA) .AND. Empty(L1_DOCPED) .AND. L1_STATUS <> "D"' +' .AND. ( L1_IFSANST == "2") '														,"BPMSTSK2E"	})	//"Orcamtos reservas - Mesa de credito"
		Aadd(aCores, {'Empty(L1_DOC) .AND. !Empty(L1_RESERVA) .AND. Empty(L1_DOCPED) .AND. L1_STATUS <> "D"' +' .AND. ( L1_IFSANST == "9") '														,"BPMSTSK3E"	})	//"Orcamtos reservas - sem analise"

	EndIf

EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Ponto de entrada para inclusão de status no orçamento³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If ExistBlock("FTVD70LG") .AND. lFtvdVer12
   aCores:=	ExecBlock("FTVD70LG",.F.,.F.,{@acores,"2"})
Endif

Return aCores

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj701VRegDºAutor  ³Vendas CRM          º Data ³  09/22/08   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Funcao que verifica a existencia  de registros dependentes  º±±
±±º          ³em outras tabelas. Retorna .T. se encontrado.               º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ Tabelas de Cliente e Vendedor                              º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function Lj701VRegD(cAliasCad)

Local lRet := .T.    //variavel que recebe .T. ou .F. da funcao ExistCpo()

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//Verifica se o registro existe.					³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If cAliasCad == "SA1" .AND.	!Empty(M->LQ_CLIENTE + M->LQ_LOJA)
	lRet := ExistCpo(cAliasCad,M->LQ_CLIENTE + M->LQ_LOJA,	1)
ElseIf cAliasCad == "SA3" .AND.	!Empty(M->LQ_VEND)
	lRet := ExistCpo(cAliasCad,	M->LQ_VEND, 1)
ElseIf cAliasCad == "SE4" .AND.	!Empty(M->LQ_CONDPG) .AND. !lAlterOrc
	lRet := ExistCpo("SE4",M->LQ_CONDPG)
EndIf

Return lRet
/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7ZeraDescºAutor  ³Vendas CRM         º Data ³  09/04/09   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Zera o desconto nos itens do aCols e recalcula os impostos  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ LOJA701													  º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7ZeraDesc()

Local nX			:= 0																	// Contador do For
Local nPosDtDProp	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_DESCPRO"})			// Posicao do Desconto proporcional
Local nPosVlItem	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VLRITEM"})][2]// Posicao do Valor do item
Local nPosValDesc	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VALDESC"})][2]// Posicao do valor de desconto
Local nLastItCalc 	:= 0

// Caso seja tipocalc == 4 e localizado vai recalcular os impostos para os itens restantes
If Len(aCols) >= 1 .Or. cPaisLoc == "ARG"
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Zera o desconto no total³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If cPaisLoc == "BRA"
		Lj7T_DescP	( 2,0 )
		Lj7T_DescV	( 2,0 )
		Lj7T_Total	( 2, LJ7T_SubTotal(2) )
	Else
		Lj7T_DescP( 2,0 )
		Lj7T_DescV( 2,0 )
		Lj7T_Total( 2, 0 )
		Lj7T_Subtotal( 2, 0 )
		For nX := 1 To Len(aCols)
			If !aColsDet[nX][Len(aColsDet[nX])]
				If aColsDet[nX][nPosDtDProp] > 0
				    If IsInCallStack("LJ7Venda") .AND. nRotina <> 4
				    	If cPaisLoc == "ARG"
				    		MaFisLoad("IT_DESCONTO", 0,nX)
				    		nLastItCalc := nX
				    	Else
							MaFisAlt("IT_VALMERC",aCols[nX][nPosVlItem],nX)
						EndIf
					Else
						MaFisLoad("IT_VALMERC",aCols[nX][nPosVlItem] + aCols[nX][nPosValDesc],nX)
						nLastItCalc := nX
					EndIf
					aColsDet[nX][nPosDtDProp] := 0
				EndIf
			EndIf
		Next nX
		If nLastItCalc > 0
	        For nX:=1 To Len(aCols)
	   	   		MaFisRecal("IT_DESCONTO",nX)
	   		Next nX
		EndIf
		nX := 1
		While MaFisFound("IT",nX)
			//Recalcula os impostos variaveis (Localizacoes), atualiza array "aTotImpsV"
			Lj7RecalImp(nX,1,,,,,,.T.)
			nX++
		End
	EndIF
EndIf

Return(Nil)

/*/
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    Lj7Timer	³ Autor ³ Vendas Cliente        ³ Data ³15/06/09  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Funcao que define timer ler abastecimento e atualizar 	  ´±±
±±³mbrowse da tela de orcamentos                             			  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Retorno   ³ Nil             											  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso       ³ SIGALOJA                                                   ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
/*/
Static Function Lj7Timer( oTimer, oMBrowse )

	Local nMil   	 := 1000                                // Valor para transformar em milesimos de segundos
	Local nSegAt 	 := SuperGetMV("MV_PCLTMP",,10)         // Segundos que a tela de orçamentos será atualizada
	Local lExecTimer := SuperGetMV("MV_PCLAPE",,.F.)        // Define se o usuario de template usura o concentrador ionics APE
	//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
	Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida
If HasTemplate("PCL") .AND. lExecTimer .AND. !lFtvdVer12

		DEFINE TIMER oTimer INTERVAL nMil*nSegAt ACTION Lj7Refresh( GetObjBrow(), oTimer ) Of oMBrowse
		oTimer:Activate()

	EndIF

Return NIL

/*/
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    Lj7Refresh	³ Autor ³ Vendas Cliente        ³ Data ³15/06/09  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Funcao que atualiza orcamentos automaticamente na tela  	  ´±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Retorno   ³ Nil             											  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso       ³ SIGALOJA                                                   ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
/*/
Static Function Lj7Refresh( oObjBrow, oTimer )
//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida
Local nRecSL1 		:= 0

If !lFtvdVer12
	nRecSL1 := SL1->(Recno())
	If ValType(oTimer) <> "U"
		oTimer:Deactivate()
		oObjBrow:Refresh(.T.)
		oObjBrow:GoTo(nRecSL1)
		oTimer:Activate()
	Else
		oObjBrow:Refresh(.T.)
		oObjBrow:GoTo(nRecSL1)
	EndIf
EndIf
Return NIL

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³LjConBonusºAutor  ³Vendas CRM          º Data ³  30/03/09   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Consulta a bonificacao para a venda atual                   º±±
±±º          ³                                                            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³LOJA701                                                     º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function LjConBonus()

Local aArea		:= GetArea()	   		 							// Armazena o posicionamento atual
Local aColsBon	:= {}					  							// aCols enviado a funcao de regra de descontos
Local aPosCpos	:= {1,2,3}											// Posicao dos campos codigo, quant. e TES no aColsBon
Local aBonus	:= {}												// Retorno da rotina de processamento de bonus

Local cCondPg	:= M->LQ_CONDPG										// Condicao de pagamento utilizada
Local cTabPreco	:= cTabPad											// Tabela de precos utilizada

Local nX		:= 0			   		 							// Auxiliar de loop
Local nPos		:= 0												// Indice de pesquisa no aColsBon
Local nPProduto	:= aScan(aHeader,{|x|AllTrim(x[2])=="LR_PRODUTO"})	// Posicao do campo Codigo
Local nPQuant	:= aScan(aHeader,{|x|AllTrim(x[2])=="LR_QUANT"})	// Posicao do campo Quantidade
Local nPTotItem	:= aScan(aHeader,{|x|AllTrim(x[2])=="LR_VLRITEM"})	// Posicao do campo Total do item
Local nPTES		:= aScan(aHeaderDet,{|x|AllTrim(x[2])=="LR_TES"})	// Posicao do campo TES

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Sintetiza os produtos validos em um acols simplificado para a³
//³rotina de regra de bonificacao                               ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
For nX := 1 to Len(aCols)
	If !aTail(aCols[nX]) .AND. !Empty(aCols[nX][nPProduto])
		If (nPos:= aScan(aColsBon,{|x|x[1] == aCols[nX][nPProduto] .AND. x[3] == aColsDet[nX][nPTES]})) == 0
			AAdd(aColsBon,{aCols[nX][nPProduto],aCols[nX][nPQuant],aColsDet[nX][nPTES],.F.})
		Else
			aColsBon[nPos][2] += aCols[nX][nPQuant]
		EndIf
	EndIf
Next nX

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Processa a regra de bonificacao³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If Len(aColsBon) > 0
	aBonus	:= LjxeRBonus(aColsBon,aPosCpos,M->LQ_CLIENTE,M->LQ_LOJA,cTabPreco,cCondPg)
EndIf

If Len(aBonus) > 0
	LjTelaBon(aBonus)
Else
	MsgInfo(STR0146) //"Nenhum produto será bonificado para a venda atual"
EndIf

RestArea(aArea)

Return Nil

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³ Lj7VLRSERIE   ºAutor³ Vendas CRM        º Data ³  18/10/09   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Validação do campo L2_NSERIE. A funcao LjVlrSerie foi        º±±
±±º          ³ substituida pela funcao LjVl2Serie                           º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ Nil                                                          º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³SIGALOJA                                                    	º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7VLRSERIE()
	Local nPosQtd	:= aScan( aHeader, { |x| AllTrim(x[2]) == "LR_QUANT" } )

	If nPosQtd > 0 .AND. !Empty(&(ReadVar()))
		If aCols[N][nPosQtd] > 1
			Alert( STR0175 ) // "A quantidade desse produto não pode ser maior que 1, pois há um número de série atrelado a ele."
			aCols[N][nPosQtd] := 1
		EndIf
	EndIf
Return

Function Lj7VL2SERIE()	// Incluida a chamada da funcao Lj7VL2SERIE para tratar casos que a chamada nao e feita pela Lj7VLRSERIE.
Return Lj7VLRSERIE()

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³ Lj7VLRENTR    ºAutor³ Vendas CRM        º Data ³  18/10/09   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Validação do campo LR_FDTENTR.                               º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ Se a data é válida ou não.                                   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³SIGALOJA                                                    	º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7VLRENTR()
	Local dDataEntrega	:= CToD( "//" )
	Local lValido		:= .F.
	Local cMensagem		:= ""

	If ReadVar() == "M->LR_FDTENTR"
		dDataEntrega := &( ReadVar() )
	EndIf

	lValido := Lj7ValEntr( dDataEntrega, @cMensagem )

	If !lValido
		Alert( cMensagem )
	EndIf
Return lValido

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³ Lj7VLRMONT    ºAutor³ Vendas CRM        º Data ³  18/10/09   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Validação do campo LR_FDTMONT.                               º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ Se a data é válida ou não.                                   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³SIGALOJA                                                    	º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7VLRMONT()
	Local dDataMontagem	:= CToD( "//" )
	Local lValido		:= .F.
	Local cMensagem		:= ""

	If ReadVar() == "M->LR_FDTMONT"
		dDataMontagem := &( ReadVar() )
	EndIf

	lValido := Lj7ValMont( dDataMontagem, @cMensagem )

	If !lValido
		Alert( cMensagem )
	EndIf

Return lValido

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³ Lj7ValEntr    ºAutor³ Vendas CRM        º Data ³  18/10/09   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Validação da data de entrega.                                º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ Se a data é válida ou não.                                   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³SIGALOJA                                                    	º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7ValEntr( dDataEntrega, cMensagem )
	Local nPosMontagem	:= aScan( aHeader, { |x| x[2] == "LR_FDTMONT" } )
	Local nPosEntrega	:= aScan( aHeader, { |x| x[2] == "LR_FDTENTR" } )
	Local dDataMontagem	:= CToD( "//" )
	Local lValido		:= .F.

	If nPosMontagem > 0
		dDataMontagem := aCols[N, nPosMontagem]
	EndIf
	If nPosEntrega > 0 .AND. dDataEntrega == Nil
		dDataEntrega := aCols[N, nPosEntrega]
	EndIf

	lValido := Lj7ValEntMon( dDataEntrega, dDataMontagem, @cMensagem )
Return lValido

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³ Lj7ValMont    ºAutor³ Vendas CRM        º Data ³  18/10/09   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Validação da data de montagem.                               º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ Se a data é válida ou não.                                   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³SIGALOJA                                                    	º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7ValMont( dDataMontagem, cMensagem )
	Local nPosMontagem	:= aScan( aHeader, { |x| x[2] == "LR_FDTMONT" } )
	Local nPosEntrega	:= aScan( aHeader, { |x| x[2] == "LR_FDTENTR" } )
	Local dDataEntrega	:= CToD( "//" )
	Local lValido		:= .F.

	If nPosMontagem > 0 .AND. dDataMontagem == Nil
		dDataMontagem := aCols[N, nPosMontagem]
	EndIf
	If nPosEntrega > 0
		dDataEntrega := aCols[N, nPosEntrega]
	EndIf

	lValido := Lj7ValEntMon( dDataEntrega, dDataMontagem, @cMensagem )
Return lValido


/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³ Lj7ValEntMon  ºAutor³ Vendas CRM        º Data ³  18/10/09   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Validação do conjunto da data de entrega e montagem.         º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ Se o conjunto é válido ou não.                               º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³SIGALOJA                                                    	º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7ValEntMon( dDataEntrega, dDataMontagem, cMensagemErro )
	Local lValido	:= .T.

	If dDataEntrega != CToD( "//" ) .AND. dDataMontagem != CToD( "//" )
		If !dDataEntrega <= dDataMontagem
			lValido := .F.
			cMensagemErro := STR0176 // "Data de entrega deve ser igual ou menor que a data de montagem"
		EndIf
	EndIf
Return lValido

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³ Lj7PegaMontagem ºAutor³ Vendas CRM      º Data ³  18/10/09   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Pega a data de montagem padrão.                              º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ cProduto: Produto utilizado para pegar a data de montagem.   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ Data de montagem padrão.                                     º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³SIGALOJA                                                    	º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7PegaMontagem( cProduto )
	Local aArea			:= GetArea()
	Local nDiasMontagem	:= GetNewPar( "MV_LJDIAMO", 0 )
	Local dDataMontagem := CTOD( "//" )
	Local nCount		:= 0

	If nDiasMontagem > 0
		DbSelectArea( "SB5" )
		DbSetOrder(1)
		If DbSeek( xFilial( "SB5" ) + cProduto )
			If SB5->B5_MONTA == "1"
				dDataMontagem := dDatabase
				// Só conta de segunda a sábado
				For nCount := 1 To nDiasMontagem
					dDataMontagem += 1
					If Dow( dDataMontagem ) == 0
						dDataMontagem += 1
					EndIf
				Next
			EndIf
		EndIf
	EndIf

	RestArea( aArea )
Return dDataMontagem

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³ Lj7PegaEntrega  ºAutor³ Vendas CRM      º Data ³  18/10/09   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Pega a data de entrega padrão.                               º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ cProduto: Produto utilizado para pegar a data de entrega.    º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ Data de entrega padrão.                                      º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³SIGALOJA                                                    	º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7PegaEntrega( cProduto )
	Local aArea			:= GetArea()
	Local nDiasEntrega	:= GetNewPar( "MV_LJDIAEN", 0 )
	Local dDataEntrega	:= CTOD( "//" )
	Local nCount		:= 0

	If nDiasEntrega > 0
		dDataEntrega := dDatabase
		For nCount := 1 To nDiasEntrega
			dDataEntrega += 1
			If Dow( dDataEntrega ) == 0
				dDataEntrega += 1
			EndIf
		Next
	EndIf

	RestArea( aArea )
Return dDataEntrega

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³ Lj7HasDtEM    ºAutor³ Vendas CRM        º Data ³  18/10/09   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Verifica se a alteração para a geração de OS na gravação do  º±±
±±º          ³ orçamento, está ativa.                                       º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ Se a alteração e os campos necessários existem.              º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³SIGALOJA                                                    	º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7HasDtEM()
	Local aArea		:= GetArea()
	Local lHasDtEM	:= .F.

	DbSelectArea( "SX3" )
	DbSetOrder( 2 )
	lHasDtEM := DbSeek( "LR_FDTMONT" ) .AND. DbSeek( "LR_FDTENTR" )

	RestArea( aArea )
Return lHasDtEM

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³ Lj7EliProdPed ºAutor³ Vendas CRM        º Data ³  18/10/09   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Efetua a eliminação do produto de um determinado pedido.     º±±
±±º          ³ Usado principalmente na troca, devolução ou eliminação de    º±±
±±º          ³ resíduo.                                                     º±±
±±º          ³ Se a OS não tiver mais produtos, ela é eliminada.            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ cPedido: Número do pedido responsável pelo item.             º±±
±±º          ³ cProduto: Código do produto a ser eliminado da OS.           º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ Nil                                                          º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³SIGALOJA                                                    	º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7EliProdPed( cPedido, cProduto )
	Local aAreaSC5			:= SC5->(GetArea())
	Local aAreaSL2			:= SL2->(GetArea())
	Local aArea				:= GetArea()
	Local nItensRestantes	:= 0
	Local aAApagar			:= {}
	Local nCount			:= 0
	Local cOrcamento		:= ""
	Local lLJ7057			:= ExistBlock( "LJ7057" )	// Ponto de entrada executado pouco antes da exclusão da ordem de serviço. Inicialmente disponibilizado para que o cliente possa cancelar algum agendamento que foi feito para a OS
	Local lFTVD7057			:= ExistBlock( "FTVD7057" )	// Ponto de entrada executado pouco antes da exclusão da ordem de serviço. Inicialmente disponibilizado para que o cliente possa cancelar algum agendamento que foi feito para a OS
	//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
	Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida
	// Verifica se o pedido tem orçamento no loja
	DbSelectArea( "SC5" )
	DbSetOrder( 1 )

	If DbSeek( xFilial( "SC5" ) + cPedido )
		cOrcamento := SC5->C5_ORCRES

		// Procura o orçamento pai que gerou o pedido
		DbSelectArea( "SL2" )
		DbSetOrder( 1 )

		If DbSeek( xFilial( "SL2" ) + cOrcamento )
			cOrcamento := SL2->L2_NUM
			// Acha a ordem de servico amarrada ao orçamento do loja
			DbSelectArea( "AB6" )
			DbSetOrder( 5 )

			If DbSeek( xFilial( "AB6" ) + cOrcamento )
				// Para cada ordem de servico existente
				While	xFilial( "AB6" )	== AB6->AB6_FILIAL .AND.;
						cOrcamento			== AB6->AB6_NUMLOJ

					nItensRestantes	:= 0
					aAApagar		:= {}

					// Pega os itens que devem ser apagados
					DbSelectArea( "AB7" )
					DbSetOrder( 1 )

					If DbSeek( xFilial( "AB7") + AB6->AB6_NUMOS )
						While	xFilial( "AB7" )	== AB7->AB7_FILIAL	.AND.;
								AB6->AB6_NUMOS		== AB7->AB7_NUMOS

							If AB7->AB7_CODPRO == cProduto
								aAdd( aAApagar, AB7->(Recno()) )
							Else
								nItensRestantes += 1
							EndIf
							AB7->(DBSkip())
						End
					EndIf

					// Apaga os itens que devem ser apagados
					If Len( aAApagar ) > 0
						For nCount := 1 To Len( aAApagar )
							AB7->( DbGoTo( aAApagar[nCount] ) )
							RecLock( "AB7", .F. )
							AB7->(DbDelete())
							AB7->(MsUnLock())
						Next
					EndIf

					// Se acabar os itens do ab7, apaga o cabeçalho da OS também
					If nItensRestantes == 0
						If lLJ7057 .AND. !lFtvdVer12
							ExecBlock( "LJ7057", .F., .F., { AB6->AB6_NUMOS } )
						EndIf
						If lFTVD7057 .AND. lFtvdVer12
							ExecBlock( "FTVD7057", .F., .F., { AB6->AB6_NUMOS } )
						EndIf
						RecLock( "AB6", .F. )
						AB6->(DbDelete())
						AB6->(MsUnLock())
					EndIf
					AB6->(DbSkip())
				End
			EndIf
		EndIf
	EndIf

	RestArea( aAreaSC5 )
	RestArea( aAreaSL2 )
	RestArea( aArea )
Return

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7ConProCatºAutor  ³Vendas CRM          º Data ³  20/12/09   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Consulta produtos pela Categoria de Produtos              	º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ nOpcao: 1 - Pesquisa de produtos na Categoria de Produtos.   º±±
±±º          ³ 		   2 - Pesquisa de produtos Equivalentes.  			    º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³LOJA701                                                     	º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function Lj7ConProCat(nOpcao, aCpoGDa)
Local aArea		 := GetArea()
Local oCategoria := LJCProdEquiv():New()
Local aRet       := {}
Local nCont      := 1
Local nPosItem	 := aPosCpo[Ascan(aPosCpo,{|x| Alltrim(Upper(x[1])) == "LR_ITEM"})][2]	    	// Posicao do Codigo do item
Local nPosProd	 := aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_PRODUTO"})][2]			// Posicao da codigo do produto
Local naCols     := Len(aCols)
Local nTamaRet   := 0
Local aTmpCols   := Array( 1, Len(aHeader) + 1 )
Local nTamItem   := TamSx3("LR_ITEM")[1]
Local nTamProd   := TamSx3("L2_PRODUTO")[1]
Local oEntProd   := Nil
Local oProduto   := Nil
Local cBkReadVar := ReadVar()																		// Backup da variavel __ReadVar

LjHeader("SLR", aCpoGDa, @aTmpCols)
aTmpCols[1][ aScan( aHeader, {|x| IsHeadRec( x[2] ) } ) ]   := 0
aTmpCols[1][ aScan( aHeader, {|x| IsHeadAlias( x[2] ) } ) ] := "SL2"
aTmpCols[1][Len(aHeader) + 1 ] := .F.

If nOpcao == 1
	oCategoria:ConsultaCat()
Else
	If !Empty(aCols[n][nPosProd])
		oEntProd := LJCEntProduto():New()
		oEntProd:DadosSet("B1_COD", aCols[n][nPosProd])
		oProduto := oEntProd:Consultar(1)

		oCategoria:TelaResult( aCols[n][nPosProd], oProduto:Elements(1):DadosGet("B1_GRUPO") )
	EndIf
EndIf

aRet 	:= oCategoria:aRetProd
nTamaRet:= Len(aRet)

For nCont := 1 To nTamaRet
	If nPosProd > 0
		If !Empty(aCols[naCols][nPosProd])
			AADD( aCols, aClone(aTmpCols[1]) )
			naCols := Len(aCols)
		EndIf

	    n := naCols
		aCols[naCols][nPosItem] := STRZERO(naCols, nTamItem)
		M->LR_ITEM		        := aCols[naCols][nPosItem]
		aCols[naCols][nPosProd]	:= PADR(aRet[nCont], nTamProd)
		M->LR_PRODUTO	        := aCols[naCols][nPosProd]
		__ReadVar               := "M->LR_PRODUTO"
		Lj7Prod(.F.)
		Lj7LinOk()

	EndIf
Next nCont

__ReadVar := cBkReadVar
RestArea( aArea )

Return Nil

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7SugVend  ºAutor  ³Vendas CRM          º Data ³  20/12/09   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Consulta produtos relacionados a sugestao de vendas       	º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³LOJA701                                                     	º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7SugVend(aCpoGDa, lSugestao,cProduto, nTipOpc)
Local aArea		 := GetArea()	   		 		                                                     // Area corrente
Local aRet       := {}                                                                              // Array de retorno
Local nCont      := 1                                                                               //variavel de contador
Local nPosItem	 := aPosCpo[Ascan(aPosCpo,{|x| Alltrim(Upper(x[1])) == "LR_ITEM"})][2]	    	// Posicao do Codigo do item
Local nPosProd	 := aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_PRODUTO"})][2]			// Posicao da codigo do produto
Local nPosVlItem := aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VLRITEM"})][2]			// Posicao do Valor do item
Local nPosEntr := aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_ENTREGA"})][2]			// Posicao da Entrega
Local naCols     := Len(aCols)                                                                                                          // variavel de Acols
Local nTamaRet   := 0                                                                                                                     //Variavel para tamanho do array aRet
Local aTmpCols   := Array( 1, Len(aHeader) + 1 )                                                                               //Acols Temporaria
Local nTamItem   := TamSx3("LR_ITEM")[1]                                                                                      //tamanho do campo item na tabela SX3
Local nTamProd   := TamSx3("L2_PRODUTO")[1]                                                                            //tamanho do campo produto na tabela SX3
Local cBkReadVar := ReadVar()						     												                          // Backup da variavel __ReadVar
Local lRet		 := .F.
                                                                                                                    // Variavel de retorno
DEFAULT aCpoGDa	 	:= {}
DEFAULT lSugestao 	:= .F.
DEFAULT nTipOpc		:= 2	// Tipo de chamada 1 pelo botao Outros na VA e 2 pelo gatilho do item

LjHeader("SLR", aCpoGDa, @aTmpCols,nTipOpc == 2)
aTmpCols[1][ aScan( aHeader, {|x| IsHeadRec( x[2] ) } ) ]   := 0
aTmpCols[1][ aScan( aHeader, {|x| IsHeadAlias( x[2] ) } ) ] := "SL2"
aTmpCols[1][Len(aHeader) + 1 ] := .F.

If Empty(cProduto)
	For nCont := 1 To Len(aCols)
		If nPosProd > 0
			If !Empty(aCols[nCont][nPosProd])
				If !Lj7VeriSug(aCols[nCont][nPosProd], @aRet)
	            	Exit
				Endif
			EndIf
		EndIf
	Next nCont
Else
	Lj7VeriSug(cProduto, @aRet)
EndIf

aRet := Lj7SugTela(@aRet,lSugestao)

If Len(aRet)>0
	LjAtuAcols(aRet)

EndIf

Return lRet


/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7VeriSug  ºAutor  ³Vendas CRM          º Data ³  20/12/09   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Consulta produtos pela Categoria de Produtos              	º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ nOpcao: 1 - Pesquisa de produtos na Categoria de Produtos.   º±±
±±º          ³ 		   2 - Pesquisa de produtos Equivalentes.  			    º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³LOJA701                                                     	º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function Lj7VeriSug(cProd, aRet)

Local cAlias		:= "LJVC"            	//Alias temporario para consulta SQL
Local cQuery        := ""                 	//Variavel de auxilio consulta SQL
Local cCateg 		:= RetSQLName("ACV")   	//Alias tabela de Categorias
Local cNprod 		:= RetSQLName("SB1")   	//Alias tabela de Produtos
Local cCategoria	:= ""                  	//variavel para categoria corrente
Local cPai          := ""                  	//variavel para produto pai
Local nPosaCols		:= 0                	//variavel de posicao de Acols
Local nPosaRet		:= 0              		//varialve de posicao em array de retorno
Default aRet       	:= {}
Default cProd		:= ""

#IFDEF TOP
	If FindFunction("LJa801ExQu")
		cQuery:= "SELECT V.ACV_CATEGO, U.ACU_CODPAI CONT FROM "+RetSQLName("ACV")+" V LEFT JOIN "+RetSQLName("ACU")+" U"
		cQuery+=  " ON V.ACV_CATEGO = U.ACU_COD"
		cQuery+=  " WHERE ACV_CODPRO = '" + cProd + "'
		cQuery+=  " AND V.D_E_L_E_T_ = ' ' AND U.D_E_L_E_T_=' '

		LJa801ExQu(cAlias,@cQuery)
		cPai := (cAlias)->CONT

		cQuery 	:= " SELECT DISTINCT C.ACV_CODPRO PRODUTO,C.ACV_CATEGO CAT , P.B1_DESC NOME FROM " + cCateg  + " C LEFT JOIN " + cNprod
		cQuery  += " P on P.B1_COD = C.ACV_CODPRO "
		cQuery += " LEFT JOIN " + RetSQLName("ACU") + " U ON C.ACV_CATEGO = U.ACU_COD "
		cQuery	+= " WHERE C.ACV_CATEGO IN (SELECT ACV_CATEGO FROM " + cCateg + " WHERE ACV_CODPRO = '" + AllTrim(cProd)
		cQuery  += "' AND ACV_SUVEND = '1'  AND " + cCateg + ".D_E_L_E_T_ = '')  AND C.ACV_SUVEND = '1' AND C.D_E_L_E_T_ = ''"
		cQuery += " AND U.ACU_CODPAI = '' "

		LJa801ExQu(cAlias,@cQuery)
		cCategoria :=(cAlias)->CAT
		If Empty(cPai)
			While (cAlias)->( !Eof() )
				If  AllTrim((cAlias)->Produto) <> AllTrim(cProd)
					nPosaCols := aScan(aCols, {|c| c[2] == (cAlias)->PRODUTO} )     // verifica se os produtos retornados ja estao no acols
				    nPosaRet := aScan(aRet, {|c| c[2] == (cAlias)->PRODUTO} )     // verifica se os produtos retornados ja estao na sugestão de vendas
				    If nPosaCols ==0  .AND. nPosaRet==0
						AAdd(aRet, {.F., 	(cAlias)->PRODUTO,(cAlias)->NOME} )
					EndIf
				EndiF
				(cAlias)->(DbSkip())
			End
		EndIf

		If !Empty(cCategoria)
			cQuery 	:= " SELECT DISTINCT C.ACV_CODPRO PRODUTO, P.B1_DESC NOME FROM  " + cCateg  + " C LEFT JOIN " + cNprod
			cQuery  += " P on P.B1_COD = C.ACV_CODPRO"
			cQuery	+= " WHERE ACV_CATEGO IN (SELECT ACU_COD FROM  " +RetSQLName("ACU") + " WHERE ACU_CODPAI = '"+ cCategoria+"'"
			cQuery  += " AND ACV_SUVEND = '1'  AND D_E_L_E_T_ = '')  AND  ACV_CATEGO <> '" + AllTrim(cCategoria) + "' AND ACV_SUVEND = '1' AND C.D_E_L_E_T_ = ''"
			LJa801ExQu(cAlias,@cQuery)
			While (cAlias)->( !Eof() )
				nPosaCols := aScan(aCols, {|c| c[2] == (cAlias)->PRODUTO} )	//verifica se os produtos retornados ja estao no acols
			    nPosaRet := aScan(aRet, {|c| c[2] == (cAlias)->PRODUTO} )		//verifica se os produtos retornados ja estao na sugestão de vendas
			    If nPosaCols ==0  .AND. nPosaRet==0
					AAdd(aRet, {.F., 	LJVC->PRODUTO,LJVC->NOME} )
				EndIf
				LJVC->(DbSkip())
			End
		EndIf
	EndIf
#ENDIF

Return .T.

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  |Lj7SugTela  ºAutor  ³Vendas CRM          º Data ³  20/12/09   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Exibe tela dos produtos que tem sugestão de vendas           	º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ aProds: array com  a sugestão de vendas dos produtos         º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³Retorna um array com os produtos selecionados              	º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³LOJA701                                                     	º±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/

Function Lj7SugTela(aProds, lSugestao)

Local oDlg       	:= Nil     								//objeto de tela
Local olstResul  	:= Nil     								//Lista de resultados
Local aHeaders   	:= {"", STR0062, STR0065} 				//##"Codigo" ##"Descrição"
Local aTamHead   	:= {20,60,150,40}     					//tamanho do cabecalho
Local oOK 			:= LoadBitmap(GetResources(),"LBOK")	//variavel de status OK
Local oNO 			:= LoadBitmap(GetResources(),"LBNO")	//variavel de status NO
Local obtnInser  	:= Nil                               	//objeto Botao de Insercao
Local aRetorno   	:= {}                               	//Array de Retorno
Default aProds   	:= {}
Default lSugestao	:= .F.

//Carrega o array do Grid
If Len(aProds)>0
	If lSugestao
   		If !lAutoExec
	   		DEFINE MSDIALOG oDlg TITLE STR0209 FROM 178,181 TO 361,689 PIXEL //Sugestoes de Venda

			// Cria o Grid de Resultado
			olstResul := TCBrowse():New( 10,10,230,60, ,aHeaders,aTamHead,;
		    		     oDlg,,,,,{||},,,,,,,.F.,,.T.,,.F.,,,)

			olstResul:SetArray(aProds)
			olstResul:bLine 		:= {||{ If(aProds[olstResul:nAt,01],oOK,oNO),aProds[olstResul:nAt,02],aProds[olstResul:nAt,03]} }
	        olstResul:bLDblClick 	:= {|| aProds[olstResul:nAt][1] := !aProds[olstResul:nAt][1],olstResul:DrawSelect() }

			obtnInser  := TButton():New( 77,215, STR0102,oDlg,{|| aRetorno :=LjRetProd(aProds), oDlg:End() },; //"Confirmar"
		                                  37,12,,,.F.,.T.,.F.,,.F.,,,.F. )

			ACTIVATE MSDIALOG oDlg CENTERED
		Else
			aRetorno :=LjRetProd(aProds)
		Endif
	Endif
EndIf

Return aRetorno

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³LjRetProd   ºAutor  ³Vendas CRM          º Data ³  20/12/09   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Consulta produtos pela Categoria de Produtos              	º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ nOpcao: 1 - Pesquisa de produtos na Categoria de Produtos.   º±±
±±º          ³ 		   2 - Pesquisa de produtos Equivalentes.  			    º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³LOJA701                                                     	º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function  LjRetProd(aGrid)
	Local aCodProd := {}              //Array com codigo de Produto
    Local nTam     := Len(aGrid)     // variavel de tamanho de Array
    Local nCont    := 1              // variavel auxiliar de contador
    Local nCodProdu:= 2              // variavel para codigo de Produto

	For nCont:=1 To nTam

		If aGrid[nCont][1]
			AADD(aCodProd, {aGrid[nCont][nCodProdu],1})
		EndIf

	Next nCont

Return aCodProd

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³LJ7Import ºAutor  ³ Vendas Cliente     º Data ³  01/10/2009 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Carrega um orcamento aberto na retaguarda para finalizacao  º±±
±±º          ³no PDV                                                      º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³Loja701                                                     º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function LJ7Import()
Local aArray 	:= {{.F.,"",""}}
Local oSim		:= LoadBitmap(GetResources(), "BR_VERDE")
Local oNao		:= LoadBitmap(GetResources(), "BR_VERMELHO")
Local oDlg      := Nil
Local oNumOrc
Local nTamDAV	:= TamSX3("L1_NUMORC")[1]
Local cNumDAV   := Space(nTamDAV)		  						// Numero do documento auxiliar de venda
Local cNumOrc  	:= Space(TamSX3("L1_NUM")[1])
Local nTamDoc   := TamSX3("L1_NUM")[1]

Local oNumDAV
Local oBtnPesq
Local oBtnOK
Local cNumCaixa := xNumCaixa()									// Codigo do usuario ativo

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Verifica se o usuario eh um caixa para poder efetuar atendimentos       ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If !IsCaixaLoja( cNumCaixa )
	Aviso( STR0056, STR0057 + Alltrim(cUserName) + ;  //"Atenção" ### "O usuário "
	STR0058, {STR0028} )  //" não poder  fazer vendas. Utilize a opção Senhas/Caixas no Menu Miscelânea para incluir um Caixa. Caso já exista um cadastrado, re-entre no sistema com uma senha de Caixa." ### "Ok"
	Return .F.
EndIf

//
//Se for PDV OFFLINE + PAF + CONCOMITANCIA, antes de importar o orçamento,
//verificaremos se o caixa está aberto, pois se estiver fechado,
//ele vai importar o orçamento e cancelar todos os itens
//
If lMvLjPdvPa .AND. LjVassConc(1)
	If !LjCxAberto( Nil,cNumCaixa )
		Return .F.
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄP¿
//³Verifica se o ambiente está configurado para integração com o       ³
//³Financial Services. Caso afirmativo, verifica se os parâmetros de   ³
//³cálculo de juros do Financial Services é igual ao parâmetro de      ³
//³cálculo de juros do Protheus para permitir o prosseguimento da venda³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄPÙ
If lUsaIntFS == NIL
	lUsaIntFS	:= SuperGetMV("MV_LJINTFS",,.F.) .And. LjUpd90Ok(, !IsBlind())
EndIf

If lUsaIntFS .AND. cMVLjIFSJu <> cMvJurTipo
	MsgStop( STR0277  +; //"O módulo controle de lojas está integrado com o Financial Services. "
		          STR0278+;//"Por esta razão, é necessário que parâmetro que indica o tipo de cálculo "
		          STR0279)  //"de juros dos títulos a receber do sistema externo (MV_LJIFSJU) esteja igual ao do ERP (MV_JURTIPO)."

	Return .F.
EndIf

aArray := {{.F.,"","",""}}

If SuperGetMV("MV_FRTIMP",,1) == 2 .AND. !lMvLjPdvPa
	//"As funcionalidades do parâmetro MV_FRTIMP não estão implementadas no SIGALOJA."
	MsgStop(STR0195)
	Return NIL
EndIf

DEFINE MSDIALOG oDlg TITLE STR0150 FROM 0,0 TO 255,353 PIXEL	// "Carregamento de Orçamentos"

@00,02 To 21,44 Label STR0006 Pixel of oDlg //Orçamento
@00,47 To 21,95 Label If(lPreVenda,STR0164,STR0165) Pixel of oDlg // "Pre-Venda","DAV"

@08,04 GET oNumOrc VAR cNumOrc SIZE 36,7 PIXEL PICTURE PesqPict("SL1","L1_NUM") ;
	ON CHANGE If(!Empty(cNumOrc),;
	(cNumOrc := StrZero(Val(cNumOrc),nTamDoc),oNumOrc:Refresh(),;
	 cNumDAV:= Space(nTamDAV),oNumDAV:Refresh(),;
	 LJ7VldCarrega( @oDlg, cNumOrc, cNumDAV )),.F.)

@08,49 GET oNumDAV VAR cNumDAV SIZE 44,7 PIXEL PICTURE PesqPict("SL1","L1_NUMORC");
ON CHANGE If(!Empty(cNumDAV),;
	(cNumDAV := StrZero(Val(cNumDAV),nTamDAV),oNumDAV:Refresh(),;
	cNumOrc:= Space(nTamDoc),oNumOrc:Refresh(),;
	LJ7VldCarrega( @oDlg, cNumOrc, cNumDAV )),.F.)

If !ExistFunc("U_FRTNUMORC")
	oNumOrc:Disable()
EndIf

DEFINE SBUTTON oBtnPesq FROM 06,105 PIXEL TYPE 14 ENABLE ONSTOP STR0151 ;	// "Pesquisar..."
	ACTION LJ7PesqOrc(@oOrcamentos, @aArray, @oNumOrc, @cNumOrc )


@ 20,02 TO 128,176 LABEL STR0006 PIXEL	// "Resultado da Pesquisa"

@ 27,04 LISTBOX oOrcamentos FIELDS HEADER "", STR0006, STR0046, If(lPreVenda,STR0164,STR0165) FIELDSIZES 7,30,70 SIZE 169,87.5 PIXEL	// "Pre-Venda","DAV","Orçamento","Cliente"

oOrcamentos:SetArray(aArray)
oOrcamentos:bLine := {|| {If(aArray[oOrcamentos:nAt,1],oSim,oNao),aArray[oOrcamentos:nAt,2],aArray[oOrcamentos:nAt,3],aArray[oOrcamentos:nAt,4]} }
oOrcamentos:bLDblClick := {|| LJ7NumClik(@oOrcamentos,@aArray,@oNumOrc,@cNumOrc,@oNumDAV,@cNumDAV)}
oOrcamentos:Disable()
oNumOrc:bLostFocus := {|| If(!Empty(cNumOrc),oBtnOK:SetFocus(),Nil) }

DEFINE SBUTTON oBtnOK FROM 115,111 PIXEL TYPE 1 ENABLE ACTION If(!Empty(cNumOrc),;
	LJ7VldCarrega( @oDlg, cNumOrc, cNumDAV ), Nil)

DEFINE SBUTTON FROM 115,141 PIXEL TYPE 2 ENABLE ACTION oDlg:End()
ACTIVATE DIALOG oDlg CENTERED

Return Nil

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±³Fun‡„o	 ³LJ7PesqOrc     ³ Autor ³ Vendas Clientes  ³ Data ³01/10/2009³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descri‡„o ³Pesquisar os Orcamentos em Aberto no Server da Retaguarda   ³±±
±±³          ³e Exibi-los Para a Selecao.                                 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³Loja701                                                     ³±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function LJ7PesqOrc(oOrcamentos, aArray, oNumOrc, cNumOrc, cOrigem, lDigitou, cNumDavImp)
Local cNumero  := ""
Local cCliente := ""
Local cOrc 	   := ""
Local aRet
Local nMvFrLmOrc:= SuperGetMV("MV_FRLMORC",,300)	// Parametrização para controle do Limite de Orçamentos a serem carregados
Local nL1NUM    := TamSX3("L1_NUM")[1]				// Tamanho do campo B1_COD
Local nA1NOME   := TamSX3("A1_NOME")[1]				// Tamanho do campo B1_COD
Local lRet 		:= .T.
Local nL1NumOrc := 0
Local cNumDavOrc:= ""
Local aBkpArray	:= {}
Local nY		:= 0
Local nTamOrcDav:= 0
Local nTpImpOrc := 1 //Baseado no parametro MV_LJTPIMO, porem não será usado no Loja, pois o Loja-PDV é somente com PAF

Default oOrcamento	:= Nil
Default oNumOrc   	:= Nil
Default cNumOrc    	:= ""
Default cOrigem    	:= ""
Default lDigitou   	:= .F.
Default cNumDavImp 	:= ""

nL1NumOrc := TamSX3("L1_NUMORC")[1]

If Empty(cNumOrc) .AND. cOrigem <> "LOJA160"
	// "Pesquisar os Orçamentos em aberto poderá levar alguns segundos."+Chr(13)+;
	// "Caso você já saiba o Número do Orçamento, digite-o e clique em Ok. Prosseguir com a pesquisa?"+Chr(13)+;
	// "Prosseguir com a pesquisa?", "Pesquisar Orçamentos em Aberto"
	If !(lDigitou)
		If !MsgYesNo(STR0152+Chr(13)+STR0153+Chr(13)+STR0154, STR0155)
			Return NIL
	  	EndIf
	EndIf
EndIf

If cOrigem == "LOJA160" .OR. lDigitou
	LJMsgRun(STR0156,,{|| aRet := FR271CMyCall("FR271CRPCOrc", {"SL1", "SA1"}, 2, nMvFrLmOrc, cOrigem,SM0->M0_CGC,,nTpImpOrc)})	// "Aguarde. Pesquisando os orçamentos em aberto..."
Else
	If !Pergunte("FRT10C",.T.)
		Return NIL
	EndIf

	LJMsgRun(STR0156,,{|| aRet := FR271CMyCall("FR271CRPCOrc", {"SL1", "SA1"}, MV_PAR01, nMvFrLmOrc,"LOJA701",SM0->M0_CGC,,nTpImpOrc)})	// "Aguarde. Pesquisando os orçamentos em aberto..."
EndIf

cOrc := aRet[2]
If Empty(cOrc)
	// "Não foi encontrado nenhum Orçamento em aberto para ser carregado!", "Atenção"
	MsgStop(STR0157, STR0015)
	lRet := .F.
ElseIf Left(cOrc,4)=="ERRO"
	// "Erro ao pesquisar os Orçamentos em aberto. Tente novamente.", "Atenção"
	MsgStop(STR0158, STR0015)
Else
	aArray := {}												// Carrega os Orcamentos
	SA1->(DbSetOrder(1))
	While !Empty(cOrc)
		cNumero  := Left(cOrc, nL1NUM )
		cOrc     := Substr(cOrc, nL1NUM + 1)

		cCliente := Left(cOrc, nA1NOME )
		cOrc     := Substr(cOrc, nA1NOME + 1)

		If LjNfPafEcf(SM0->M0_CGC)
			cNumDavOrc := Left(cOrc, nL1NumOrc )
			cOrc     := Substr(cOrc, nL1NumOrc + 1)
			AAdd(aArray, {(cOrigem == "LOJA160"), cNumero, cCliente, cNumDavOrc})
		Else
			AAdd(aArray, {.F., cNumero, cCliente})
		EndIf
	End

    If lDigitou

    	For nY := 1 To Len(aArray)

        	If Len(aArray[nY][4]) <> Len(cNumDavImp)
            	nTamOrcDav := Abs(Len(aArray[nY][4]) - Len(cNumDavImp))
         	EndIf

            If Alltrim(aArray[nY][4]) == Right(cNumDavImp,Len(aArray[nY][4]) - nTamOrcDav)

            	Aadd(aBkpArray,{aArray[nY][1],aArray[nY][2],aArray[nY][3],aArray[nY][4]})

			EndIf

 		Next nY

        aArray := {}

        aArray := aClone(aBkpArray)

	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Atualiza as Informacoes na Tela... ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	cNumOrc := Space(nL1NUM)
	If cOrigem <> "LOJA160"
		oNumOrc:Refresh()
		oOrcamentos:aArray := aArray
		oOrcamentos:Refresh()
		oOrcamentos:Enable()
		oOrcamentos:SetFocus()
	EndIf
EndIf

Return lRet


/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºFun‡„o	 ³LJ7NumClik   ³ Autor ³ Vendas Clientes  ³ Data ³01/10/2009º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDescri‡„o ³Marcar o Orcamento a Ser Finalizado.                      º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso		 ³Loja701                                                   º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Static Function LJ7NumClik(oOrcamentos, aArray, oNumOrc, cNumOrc,;
						   oNumDAV	  , cNumDAV)
If aArray[oOrcamentos:nAt,1]
	cNumOrc := Space(TamSX3("L1_NUM")[1])
	cNumDAV := Space(TamSX3("L1_NUMORC")[1])
	aArray[oOrcamentos:nAt,1] := .F.
Else
	AEval(aArray, {|x| x[1]:=.F.})
	aArray[oOrcamentos:nAt,1] := .T.
	cNumOrc := aArray[oOrcamentos:nAt,2]
	cNumDAV := aArray[oOrcamentos:nAt,4]
	oOrcamentos:Refresh()
EndIf
oNumOrc:Refresh()
oNumDAV:Refresh()
Return NIL

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³LJ7VldCarrega   ºAutor  ³Vendas Clientes º Data ³  05/10/2009 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Validar e carregar o orcamento selecionado.                  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ oDlg 	: Dialog de importancao de orcamento				º±±
±±º		     ³ cNumOrc  : Numero do Orcamento                               º±±
±±º          ³ cNumDAV  : Numero do DAV                                     º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ Loja701                                                      º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function LJ7VldCarrega( oDlg, cNumOrc, cNumDAV, cOrigem )
Local aRet       := {}						// Array de retorno
Local cRet		 := ""						// Retorno de String
Local xOrc 		 							// Orcamento
Local cCliente   := ""
Local cLojaCli   := ""
Local cTipoCli   := ""
Local aSL1		 := {}						// Array com os campos do SL1
Local aSL2		 := {}						// Array com os campos do SL2
Local aSL4  	 := {}						// Array com os campos do SL4
Local cL1Filial
Local cL1Cliente := ""
Local cField     := ""
Local cProduto	 := ""						// Código do produto do aSL2
Local cLstProd	 := ""						// Lista de produtos caso não existam no PDV
Local nI         := 0
Local nNumItem   := 0
Local lRet       := .T.
Local lAchouProd := .F.						// Verifica se o produto do aSL2 existe no ambiente
Local nW 		:= 0 						// Contador no aRet[3]
Local cTexto    := ""						// Texto de produto
Local lOrigPAF	:= .T.                      // Verifica se foi acionado pelo PAF ECF
Local oFontMsg								// Font das Menssagens
Local oDlgMsg								// Tela
Local oMemoMsg								// Objeto de tela Meno
Local nMvFrtImp	:= SuperGetMV("MV_FRTIMP",,1)
Local nPosL1NUM := 0
Local lGE		:= ExistFunc("LjUP104OK") .AND. LjUP104OK() // Validação do Conceito Garantia Estendida
//³Release 11.5 - Cartao Fidelidade³
Local lLjcFid 	:= SuperGetMv("MV_LJCFID",,.F.)	.AND. CrdxInt()			//Indica se a recarga de cartao fidelidade esta ativa
Local cNumCFid	:= ""						//Numero do cartao fidelidade
Local dDatCFid  := ""						//Data de validade da recarga do cartao fidelidade
Local nValCFid  := 0						//Valor da recarga/pagamento do cartao fidelidade
Local cMoeda	:= SuperGetMv("MV_SIMB1")	//Simbolo da moeda principal

Local cCliCGC	:= ""
Local cOrcRes	:= ""
Local cPedRes	:= ""
Local lCFRetPos := .F.
Local lImpDesc	:= SuperGetMv("MV_LJIPDES",,.F.)		// Define o tratamento para desconto na importacao do orçamento

Default oDlg     	:= Nil
Default cOrigem  	:= ""

If !LjNfPafEcf(SM0->M0_CGC)
	lOrigPAF := .F.
EndIf

If lRet
	If Empty(cNumDAV)
		LJMsgRun( STR0156 + cNumOrc + "...", NIL, { || aRet := FR271CMyCall( "FR271CRPCLoad", { "SA1", "SL1", "SL2", "SL4", "SF4", "SB2"}, cNumOrc, .F., cOrigem , lOrigPAF , Nil , lGE ) } )
	Else
		LJMsgRun( STR0156 + cNumOrc + "...", NIL, { || aRet := FR271CMyCall( "FR271CRPCLoad", { "SA1", "SL1", "SL2", "SL4", "SF4", "SB2"}, cNumDAV, .T., cOrigem , lOrigPAF , Nil , lGE ) } )
	EndIf

	cRet := aRet[1]
	If nMvFrtImp == 1 .OR. (Left( cRet, 2 ) <> "OK")
		xOrc := aRet[2]
	Else
		xOrc := {aRet[4], aRet[5], aRet[6]} // Com o parametro igual a 2 deve importar como Array
	EndIf
	cRet := Trim( cRet )

	If Left( cRet, 2 ) == "OK"
		cOrcRes	:= FR271CAField( xOrc, "L1_ORCRES" )	// Codigo do orcamento da reserva
		cPedRes	:= FR271CAField( xOrc, "L1_PEDRES" )	// Codigo do pedido da reserva
		lCFRetPos := Empty(cPedRes) .And. !Empty(cOrcRes) .And. ExistFunc("Lj140ImpOrc") //Verifica se eh orcamento (com itens de RETIRA POSTERIOR) apenas para finalizacao (impressao do Cupom Fiscal)

	    If cOrigem <> "LOJA160"
	  		lRet := MsgYesNo(STR0168+ If(lPreVenda,STR0166,STR0167)+"?", STR0001) // "Confirma o carregamento " ### "?", "da Pre-Venda" "do DAV" "Atenção"
		EndIf

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Realiza a gravacao do SA1 caso nao exista ou algum campo foi alterado³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If lRet
			If Len( aRet[3] ) > 0
				If ( nI := AScan( aRet[3], { |x| x[1] == "A1_COD" } ) ) > 0
					cCliente 	:= aRet[3][nI][2]
					nI			:= AScan( aRet[3], { |x| x[1] == "A1_LOJA" } )
					cLojaCli	:= IIF( nI == 0, Space( Len( SA1->A1_LOJA ) ), aRet[3][nI][2] )
					nI			:= AScan( aRet[3], { |x| x[1] == "A1_TIPO" } )
					cTipoCli	:= IIF( nI == 0, Space( Len( SA1->A1_TIPO ) ), aRet[3][nI][2] )
					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³Se Registro do SA1 no front nao existir ou conteudo de algum campo for diferente da retaguarda atualiza registro³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					lNovoCliente := IIF( SA1->( DbSeek( xFilial( "SA1" ) + cCliente + cLojaCli ) ), .F. , .T. )

					If CrdSa1Alte( aRet[3] )
						FR271BGeraSL( "SA1", aRet[3], lNovoCliente )
					EndIf
				EndIf
			EndIf

   		    If nMvFrtImp == 1
		    	//Alimenta dados SL1
			  	For nI := 1 TO SL1->(FCount())
					cField := SL1->(FieldName(nI))		//pega nome do campo

					If cField == "L1_NUMORIG"
						aAdd( aSL1, { cField, FR271CAField( xOrc, "L1_NUM" )} ) //Numero do Orçamento de origem na retaguarda
					ElseIf cField == "L1_NUMORC"
						aAdd( aSL1, { cField, FR271CAField( xOrc, "L1_NUMORC" ) } )	//Numero do Dav ou Pre-Venda
					ElseIf cField == "L1_TPORC" .AND. lPreVenda
						aAdd( aSL1, { cField, "P" } )
					Else
						aAdd( aSL1, { cField, FR271CAField( xOrc, cField ) } )	//insere valor no array
					EndIf
				Next nI

				cLstProd	:= ""

			    //Alimenta dados SL2
		  		For nNumItem := 1 TO FR271CQtdSL2( xOrc )
			    	aAdd( aSL2, {} )
				  	For nI := 1 TO SL2->(FCount())
						cField := SL2->(FieldName(nI))		//pega nome do campo

						If cField == "L2_NUMORIG"
							aAdd( aSL2[nNumItem], { cField, FR271CAField( xOrc,"L2_NUM", nNumItem ) } )	// Numero do Orçamento de origem na retaguarda
						Else
							aAdd( aSL2[nNumItem], { cField, FR271CAField( xOrc, cField, nNumItem ) } )	//insere valor no arra
						EndIf

						//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
						//³Release 11.5 - Cartao Fidelidade³
						//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
						If lLjcFid
							If cField == "L2_NUMCFID" .AND. !Empty(FR271CAField( xOrc, cField, nNumItem ))
								cNumCFid := FR271CAField( xOrc, cField, nNumItem )
							Endif

							If cField == "L2_DTSDFID" .AND. !Empty(FR271CAField( xOrc, cField, nNumItem ))
								dDatCFid := FR271CAField( xOrc, cField, nNumItem )
							Endif

							If cField == "L2_VLRCFID" .AND. FR271CAField( xOrc, cField, nNumItem ) > 0
								nValCFid := FR271CAField( xOrc, cField, nNumItem )
							Endif

						EndIf

					Next nI

					//Valida se os produtos carregados existem no PDV - analisa todos os produtos carregados como é efetuado no SIGAFRT
					cProduto	:=	aSL2[nNumItem][AScan( aSL2[nNumItem], { |x| x[1] == "L2_PRODUTO" } )][2]
					If !Empty(cProduto)
						lAchouProd	:= LjSB1SLK( cProduto, Nil, nModulo==23  ) //Faz a pesquisa do codigo de produto importado
						If !lAchouProd
						    cLstProd:=	cLstProd + AllTrim(cProduto) + ", "
						    lRet	:=	.F.
						EndIf
					EndIf
				Next nNumItem

				If !lRet
					cLstProd	:= Subs(cLstProd,1,Len(cLstProd)-2)
					MsgStop(STR0281 + CHR(9) + CHR(13) + ;			// "Produto(s) não cadastrado(s) na base de dados do PDV. Produto(s):  "
							AllTrim(cLstProd) + CHR(9) + CHR(13) +;
							STR0282 ) 								// "Para finalizar a venda é necessário realizar o(s) cadastro(s)."
				EndIf

			    If lRet // Se todos os produtos existem, carrega o orçamento e gera os registros
					//Alimenta dados SL4
			  		For nNumItem := 1 TO FR271CSL4Qtd( xOrc )
				    	aAdd( aSL4, {} )
					  	For nI := 1 TO SL4->(FCount())
							cField := SL4->(FieldName(nI))		//pega nome do campo
							aAdd( aSL4[nNumItem], { cField, 	FR271CAField( xOrc, cField, nNumItem ) } )	//insere valor no arra
						Next nI
					Next nNumItem
				EndIf
			Else
				nPosL1NUM := aScan( aRet[4][1], { |x| x[1] == "L1_NUM" })
				//Alimenta dados SL1
				For nI := 1 TO Len(aRet[4][1])
					cField := cValToChar(aRet[4][1][nI][1])		//pega nome do campo

					If cField == "L1_NUMORIG"
						cNumOrc := aRet[4][1][nPosL1NUM][2]
						aAdd( aSL1, { cField, cNumOrc} ) //Numero do Orçamento de origem na retaguarda
					ElseIf cField == "L1_TPORC" .AND. lPreVenda
						aAdd( aSL1, { cField, "P" } )
					Else
						aAdd( aSL1, aRet[4][1][nI])	//insere valor no array
					EndIf
				Next nI

				cLstProd	:= ""

			    //Alimenta dados SL2
			  	For nNumItem := 1 TO Len(aRet[5])
				    aAdd( aSL2, {} )
				  	For nI := 1 TO Len(aRet[5][nNumItem])
						cField := aRet[5][nNumItem][nI][1]		//pega nome do campo

						If cField == "L2_NUMORIG"
							aAdd( aSL2[nNumItem], { cField, cNumOrc } )	// Numero do Orçamento de origem na retaguarda
						Else
							aAdd( aSL2[nNumItem], aRet[5][nNumItem][nI] )	//insere valor no array
						EndIf

						//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
						//³Release 11.5 - Cartao Fidelidade³
						//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
						If lLjcFid
							If cField == "L2_NUMCFID" .AND. !Empty(aRet[5][nNumItem][nI]) //(FR271CAField( cOrc, cField, nNumItem ))
								cNumCFid := aRet[5][nNumItem][nI] //FR271CAField( cOrc, cField, nNumItem )
							Endif

							If cField == "L2_DTSDFID" .AND. !Empty(aRet[5][nNumItem][nI]) //(FR271CAField( cOrc, cField, nNumItem ))
								dDatCFid := aRet[5][nNumItem][nI] //FR271CAField( cOrc, cField, nNumItem )
							Endif

							If cField == "L2_VLRCFID" .AND. aRet[5][nNumItem][nI] > 0 //FR271CAField( cOrc, cField, nNumItem ) > 0
								nValCFid := aRet[5][nNumItem][nI] //FR271CAField( cOrc, cField, nNumItem )
							Endif

						EndIf
					Next nI

					//Valida se os produtos carregados existem no PDV - analisa todos os produtos carregados como é efetuado no SIGAFRT
					cProduto	:=	aSL2[nNumItem][AScan( aSL2[nNumItem], { |x| x[1] == "L2_PRODUTO" } )][2]
					If !Empty(cProduto)
						lAchouProd	:= LjSB1SLK( cProduto, Nil, nModulo==23  ) //Faz a pesquisa do codigo de produto importado
						If !lAchouProd
						    cLstProd:=	cLstProd + AllTrim(cProduto) + ", "
						    lRet	:=	.F.
						EndIf
					EndIf
				Next nNumItem

				If !lRet
					cLstProd	:= Subs(cLstProd,1,Len(cLstProd)-2)
					MsgStop(STR0281 + CHR(9) + CHR(13) + ;			// "Produto(s) não cadastrado(s) na base de dados do PDV. Produto(s):  "
							AllTrim(cLstProd) + CHR(9) + CHR(13) +;
							STR0282 ) 								// "Para finalizar a venda é necessário realizar o(s) cadastro(s)."
				EndIf

				If lRet // Se todos os produtos existem, carrega o orçamento e gera os registros
					//Alimenta dados SL4
				  	For nNumItem := 1 TO Len(aRet[6])
					    aAdd( aSL4, {} )
				  		For nI := 1 TO Len(aRet[6][nNumItem])
							cField := aRet[6][nNumItem][nI][1]		//pega nome do campo
							aAdd( aSL4[nNumItem], aRet[6][nNumItem][nI] )	//insere valor no arra
						Next nI
					Next nNumItem
				EndIf
			EndIf

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Release 11.5 - Cartao Fidelidade³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If !Empty(cNumCFid) .AND. !Empty(dDatCFid) .AND. nValCFid > 0
				If !MsgYesNo (STR0206 + cNumCFid + STR0207 + AllTrim(cMoeda) + " " + AllTrim(TRANSFORM(nValCFid,'@E 99,999,999.99')) + " ? " )//"Confirma a importacao da recarga do cartão fidelidade "#" no valor de "
					If !lAutoExec
						MsgStop (STR0208)//"Importacao Cancelada !"
					Else
						Conout(STR0208)//"Importacao Cancelada !"
					EndIf
					Return (.F.)
				EndIf
			EndIf

			If ExistBlock("LJ7073")
		   		lRet :=	ExecBlock("LJ7073",.F.,.F.,{aSL1, aSL2, aSL4})
		   	EndIf

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Caso o parametro do novo metedo de tratamento de desconto no total do orc. importado ³
			//³esteja habilitado vai ratear o valor do desconto no total entre os itens.   			³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If lRet .AND. lImpDesc
				Lj7RatDesc(aSL1, aSL2)
		   	EndIf

		    If lRet // Se todos os produtos existem, carrega o orçamento e gera os registros
				lGrava := Lj7GrvOrc( aSL1, aSL2, aSL4, .F., .T. )[1]

				If lCFRetPos .And. nModulo == 12 //Verifica se eh orcamento (com itens de RETIRA POSTERIOR) apenas para finalizacao (impressao do Cupom Fiscal)
					lRet := MsgYesNo(STR0306, STR0001) //"Confirma a impressão do cupom fiscal?"
					If lRet
						If !lIsPafNfce
							lRet := Lj140ImpOrc( Nil, SL1->L1_CLIENTE, SL1->L1_LOJA, @cCliCGC )
							If lRet
								MsgAlert(STR0308) //"Impressão do cupom concluída!"
							Endif
						EndIf
						
						aSL1 := {}
						aAdd(aSL1, {"L1_SITUA"	, "00"} ) 		// "00" - Venda Efetuada Com Sucesso
						FR271BGeraSL("SL1", aSL1, .F.) //Atualiza SL1
					Endif
				Endif

				If lGrava .AND. cOrigem <> "LOJA160" .AND. !lCFRetPos

	   		  		//Grava arquivo na retaguarda para nao permitir importar esse orcamento novamente
			        FR271HRPCImpOrc(SL1->L1_NUM,,,.T.)

					//Abre tela com orçamento importado
					Lj7Venda("SL1", SL1->(Recno()), 4)

				EndIf

				// Se existir o objeto o mesmo é finalizado
				If oDlg <> Nil
				    // Fecha janela orcamento
    		  		oDlg:End()
				Endif

			EndIf

	    EndIf
	ElseIf Left( cRet, 8 ) == "EXPIRADO"
		Help( " ", 1, "DTVALIDADE" )
	ElseIf Left( cRet, 7 ) == "VENDIDO"
		Help( " ", 1, "VENDIDO" )
	ElseIf Left( cRet, 8 ) == "NOTFOUND"
		// "O Orçamento " ### " não foi encontrado na Retaguarda.", "Atenção"
		MsgStop( STR0159 + cNumOrc + STR0160, STR0001 )
	ElseIf Left( cRet, 11 ) == "JAIMPORTADO"
		// "O Orçamento "###" já foi importado da Retaguarda."
		MsgStop( STR0159+ xOrc + STR0162 , STR0001 )
	ElseIf Left( cRet, 10 ) == "SEMESTOQUE"
			If Len(aRet[3]) > 0
				//"Os produtos abaixo nao possuem estoque. O orçamento " ## " não será importado."
				cTexto := STR0191 + Alltrim(xOrc) + STR0192 + Chr(10) + Chr(10)
				For nW := 1 To Len(aRet[3])
					// "Código do Produto: "
					cTexto += STR0193 + Alltrim(aRet[3][nW][1]) + "/" + AllTrim(aRet[3][nW][2]) + Chr(10)
				Next nX

				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Monta tela com as informacoes da NCC nao baixada/estornada³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

				DEFINE FONT oFontMsg NAME "ARIAL" SIZE 08,17 BOLD
				DEFINE MSDIALOG oDlgMsg TITLE STR0194 From 3,0 to 340,417 PIXEL // "Verificacao de Estoque"
				@ 5,5 GET oMemoMsg  VAR cTexto MEMO SIZE 200,145 OF oDlgMsg PIXEL
				oMemoMsg:oFont:=oFontMsg
				DEFINE SBUTTON  FROM 153,175 TYPE 1 ACTION oDlgMsg:End() ENABLE OF oDlgMsg PIXEL
				ACTIVATE MSDIALOG oDlgMsg CENTER
			EndIf
	ElseIf Left( cRet, 10 ) == "SEMDAV/PRE"	  //Valida quando PDV(PAF-ECF) se orçamento foi gerado em retaguarda PAF-ECF
		MsgStop( STR0240 + cNumOrc + STR0239) //"Orçamento: " ### " não possui número de DAV ou Pré-Venda. Em ambiente PAF-ECF não é permitido importar Orçamento que não seja proveniente de um DAV ou Pré-Venda! Verifique se o ambiente que gerou o Orçamento esta habilitado para operar em modo PAF-ECF com DAV ou Pre-Venda."
		lRet := .F.

	ElseIf Left( cRet, 7 ) ==  "NOGEPDV" // Valida quando PDV(PAF-ECF) se orçamento tiver item Garantia Estendida porem o pdv não está configurado para esta funcionalidade.
		MsgStop( STR0159 + cNumOrc + STR0333 + CRLF +; //#STR0159->"O orçamento " ##STR0333->" possui item com garantia estendida, entretanto esta funcionalidade não está configurada para este PDV."
				 STR0159 + STR0192 , STR0015 ) //#STR0159->"O orçamento " ##STR0192->" não será importado." ###STR0015->Atenção
	Else
		// "Erro ao carregar o Orçamento " ### ". Tente novamente.", "Atenção"
		MsgStop(STR0015 + cNumOrc + STR0161, STR0001 )
	EndIf
EndIf

Return Nil

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºFun‡„o	 ³LJ7CancImp   ³ Autor ³ Vendas Cliente s  ³ Data ³16/10/2009º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDescri‡„o ³Cancela o Orcamento importado e libera para nova importaçãoº±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso		 ³Loja701                                                    º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Static Function LJ7CancImp()
Local cNumOrig:= SL1->L1_NUMORIG
Local cNomeCli:= ""
Local cCgcCli	:= ""
Local cCCF		:= ""
Local cCoo		:= ""
Local lPafMd5 := SL1->(FieldPos("L1_PAFMD5")) > 0 .AND. FindFunction("LjxPafMd5")

//Verifica se Orçamento foi importado e efetua o cancelamento
If !(Empty(cNumOrig))

	//Marca Orçamento como cancelado
	RecLock("SL1", .F.)
	REPLACE SL1->L1_STORC	WITH "C"
	
	If LjHabDelPaf()
		If !lIsPafNfce
			IfPegCupom( nHdlECF, @cCoo )
			IFStatus(nHdlECF, "35", @cCCF)
		EndIf
		
		REPLACE SL1->L1_DOC		WITH cCoo
		REPLACE SL1->L1_NUMCFIS	WITH cCoo
		REPLACE SL1->L1_CONTDOC	WITH cCCF
	EndIf

	SL1->(MsUnlock())

	If lPafMd5
		RecLock("SL1", .F.)
		REPLACE SL1->L1_PAFMD5 WITH LjxPafMd5("SL1")
		SL1->(MsUnlock())
	EndIf

	//Remove Arquivo via RPC liberando o orçamento na retaguarda para nova importação
	FR271CMyCall("FR271HDArq", {"SL1"} , cNumOrig)
Else

	cNomeCli := LjRetNomeC()

	If Type("M->LQ_CGCCLI") <> "U"
		cCgcCli := M->LQ_CGCCLI
	EndIf

	//Quando orçamento gravado, marca como cancelado para não realizar novo cancelamento na RedZ
	If !(Empty(SL1->L1_NUM))
		RecLock("SL1", .F.)
		REPLACE SL1->L1_STORC WITH "C"
		SL1->(MsUnlock())

		If lPafMd5
			RecLock("SL1", .F.)
			REPLACE SL1->L1_PAFMD5 WITH LjxPafMd5("SL1")
			SL1->(MsUnlock())
		EndIf
	EndIf

	//Grava dados tabela MDZ
	If FindFunction("LjxGrvMdz")
		LjxGrvMdz("R4", Nil, SL1->L1_NUM, cNomeCli, cCgcCli)
	EndIf
EndIf

Return NIL

/*/
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍ»±±
±±ºFun‡„o	 ³Lj7aTitSet   ³ Autor ³ Vendas Cliente s  ³ Data ³16/10/2009º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDescri‡„o ³Lj7aTitSet                                                 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso		 ³Loja701                                                    º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
/*/

Function Lj7aTitSet(xValue)
Default xValue := {}
	If ValType(xValue) == "A"
		aTitImp := AClone(xValue)
	EndIf
Return

/*/
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍ»±±
±±ºFun‡„o	 ³Lj7aTitGet   ³ Autor ³ Vendas Cliente s  ³ Data ³16/10/2009º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDescri‡„o ³Lj7aTitGet                                                 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso		 ³Loja701                                                    º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
/*/

Function Lj7aTitGet()
Return aTitImp


/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³LJ7NFTroca      ºAutor  ³Vendas Clientes º Data ³  08/06/2010 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Permite informar qual o docto. sera emitido na venda         º±±
±±º			 ³ referente a uma operacao de troca.(Nota/Cupom)               º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ lTroca : Valida se realizando rotina de troca				º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ Loja701                                                      º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function LJ7NFTroca( lTroca )

Default lTroca	:= .F.

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Permite informar qual o docto. sera emitido na venda  ³
//³referente a uma operacao de troca.(Nota/Cupom )       ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lTroca
	Lj7ValCli()
EndIf

Return(Nil)

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³LA701SetVp      ºAutor  ³Vendas Clientes º Data ³  29/09/2010 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Definir os atributos do movimento de venda perdida	        º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ 																º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ Loja701                                                      º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function LA701SetVp(cMotivo,cJust,lDisp)
Local lRet := .F.
If oMoviVp != NIL
	lRet := oMoviVp:SetItemMv(n,cMotivo,cJust,lDisp)
Endif
Return lRet

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³LA701RemVp      ºAutor  ³Vendas Clientes º Data ³  16/10/2010 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Remover item de venda da colecao						        º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ 																º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ Loja701                                                      º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function LA701RemVp()
Local lRet := .F.
If oMoviVp != NIL
	lRet := oMoviVp:RmItem(n)
Endif
Return lRet


/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³LA701GetVp      ºAutor  ³Vendas Clientes º Data ³  29/09/2010 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Obter o objeto do movimento de venda perdida	   				º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ 																º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ Loja701                                                      º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function LA701GetVp()

Return oMoviVp

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³LA701KilVp      ºAutor  ³Vendas Clientes º Data ³  04/10/2010 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Eliminar o objeto do movimento de venda perdida  				º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ 																º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ Loja701                                                      º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function LA701KilVp()

If oMoviVp <> Nil

	oMoviVp:FreeObj()

	FreeObj(oMoviVp) //LIBERAR OBJETO
	oMoviVp := Nil

EndIf

Return Nil

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³Lj7VLDUS   ³ Autor ³ Vendas Cliente       ³ Data ³ 19/10/10 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Verifica Usuario pertencente a Vendedor e valida a operacao³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ ExpL1:= Lj7VLDUS()                                         ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ Nil														  ³±±
±±³          ³ 															  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Retorno	 ³ ExpL1 = .F.             									  ³±±
±±³          ³                                     						  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701 													  ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7VldUs()
Local cVend      := ""                             											// Vendedor Atual do Item
Local cCodUsVend := ""                             											// Codigo Usuario do Item
Local cIdUser    := ""																		// Variavel de Retorno da Autenticação do Usuario
Local cTpComiss	 := SuperGetMv("MV_LJTPCOM",,"1")  											// Tipo de calculo de comissao utilizado (1-Para toda a venda (padrao),2-Por item, 3-Por item + Controle Usuarios/Vendedores)
Local cVlReadVar := ""                                      								// Armazena ReadVar()
Local lRet       := .F.                            											// Variavel de Retorno
Local aAreaSA3	 := {}              														// Armazena Posicao Atual da Tabela SA3
Local nPosVen	 := 0																	  	// Posicao do vendedor


//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Verifica Parametrizacao³
//³Verifica Release 11.5  ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If !(cTpComiss == "3")
	lRet := .T.
	Return (lRet)
EndIf

nPosVen := aPosCpo[Ascan(aPosCpo,{|x| Alltrim(Upper(x[1])) == "LR_VEND"})][2]

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Valida o codigo do vendedor³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

If ValType(aCols) == "A" .AND. !Empty(aCols[n][nPosVen])
	cVend := aCols[n][nPosVen]
Else
	cVend := ""
Endif

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Grava Posicao Atual do ReadVar³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
cVlReadVar := __ReadVar
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Grava Posicao Atual da Tabela SA3³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
aAreaSA3 := SA3->(GetArea())
//
If Empty(cVend)
	lRet := (.T.)
	Return (lRet)
Else
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Seleciona Tabela de Vendedores [SA3]³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	DbSelectArea("SA3")
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Seta Indice SA3 (1) // Filial+Codigo Vendedor³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	DbSetOrder(1)
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Realiza procura do Codigo do Vendedor = "cVend" na Tabela SA3³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
   	If DbSeek(xFilial("SA3")+cVend)
		cCodUsVend := SA3->A3_CODUSR
   	EndIf
EndIf
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Valida o codigo do usuario vinculado ao Vendedor	³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If !Empty(cCodUsVend)
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Caso o Codigo Vendedor do Item seja = Codigo Vendedor Logado³
	//³Libera a alteracao no item								   ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If cCodUsVend == __cUserId
		lRet :=	(.T.)
   	Else
  		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Exibe a Tela se caso o usuario responsavel digite a senha de³
		//³ usuario ele altera o item para o Vendedor Logado           ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
      	FWAuthUser(@cIdUser)
		If (cCodUsVend == cIdUser)
			lRet := (.T.)
       	Else
           	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³	MsgAlert: Usuario/Senha Nao Confere! Sera Solicitada o Usuario/Senha de Superior.³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			//MsgAlert(STR0232)
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Caso o Usuario nao autentique seu login/senha,                   ³
			//³Sera solicitada a Tela de Login/Senha de Autenticacao do Superior³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
        	If FWAuthSuper(cCodUsVend)
				lRet := (.T.)
			EndIf

   	   	EndIf
   	EndIf
Else
	//Tela de Login/Senha de autenticacao do superior (do usuario logado).
	If FWAuthSuper(__cUserId)
		lRet := (.T.)
	Else
		MsgAlert( STR0293 + CRLF + STR0294 ) //"Usuário sem superior cadastrado ou senha do superior nao confere.A alteracao neste caso e permitida apenas mediante autorizacao do superior."
	EndIf
EndIf
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Devolve Posicao Inicial da Tabela³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
RestArea(aAreaSA3)
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Devolve Posicao Inicial do ReadVar³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
__ReadVar := cVlReadVar

Return (lRet)


/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³LJ7VldVp   ³ Autor ³ Leandro Nogueira     ³ Data ³ 02/12/10 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Verifica se a funcionalidade de venda perdida esta ativa	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ ExpL1:= LJ7VldVp()                                         ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ Nil														  ³±±
±±³          ³ 															  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Retorno	 ³ ExpL1 = .T.             									  ³±±
±±³          ³                                     						  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701 													  ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/

Function LJ7VldVp ()

Local lRet := .F. 	//Retorno

// Habilita funcionalidade de movimento de venda perdida
lRet := SuperGetMV ("MV_LJMVPE",,.F.)	.AND. FindFunction("LOJA7004") 	.AND.;
				FindFunction("LOJA7005")		.AND. FindFunction("LOJA7006") 	.AND.;
				FindFunction("LOJA730") 		.AND. FindFunction("LOJA740") 	.AND.;
				FindFunction("LOJA750") 		.AND. AliasIndic("MBQ") 		.AND.;
				AliasIndic("MBR")
Return lRet

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³ Lj7AltOrc ³ Autor ³Vendas CRM            ³ Data ³ 04/03/11 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Alteracao do orcamento ja criado                           ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ ExpL1:= Lj7AltOrc()                                        ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ Nil														  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Retorno	 ³ Logico. Se ocorreu tudo ok com a alteracao                 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ SIGALOJA													  ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/

Function Lj7AltOrc()

Local cOrcamento := SL1->L1_NUM 					 // Numero do oarçamento
Local cPedido    := ""								 // Numero do pedido
Local cReserva   := ""                               // Numero da reserva
Local nA	   	 := 0                                // Controle de loop
Local nB	     := 0                                // Controle de loop
Local nPosItem   := 0                                // Posicao do Campo LR_ITEM no aHeader
Local nPosProduto:= 0                                // Posicao do Campo LR_PRODUTO no aHeader
Local nPosEntr	 := 0                                // Posicao do Campo LR_ENTREGA no aHeader
Local aNovProd   := {}                               // Armazana os itens realmente alterados
Local aSl1Del    := {}                               // Armazena os cabecalhos dos ormanetos as serem deletados
Local aProdPed   := {}                               // Armazena os itens que sao passados para a funcao Lj7Pedido
Local cFilialOri := ""                               // Carrega a Filial Origem do pedido
Local cOrcOri    := ""                               // Carrega o nu. orcamento de origem
Local cBkpFilial := ""                               // BKP para cFilAnt
Local lAltOrc  	 := (SuperGetMV("MV_LJCHGTP",,2) == 1 .AND. SuperGetMV("MV_LJALTEN", NIL, .F.))	// Verificacao dos parametros de alteracao
Local lRet       := .T.

aNovProd := {}

If lAltOrc

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Adiciona as novas alteracoes no array para ser comprado                  ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	nPosItem	:= aScan(aHeader, { |x| AllTrim(x[2]) == "LR_ITEM" } )
	nPosProduto	:= aScan(aHeader, { |x| AllTrim(x[2]) == "LR_PRODUTO" } )
	nPosEntr	:= aScan(aHeader, { |x| AllTrim(x[2]) == "LR_ENTREGA" } )

	If (nPosProduto > 0  .AND. nPosEntr > 0)
		For nA := 1 To Len(aCols)
			If !aCols[nA][Len(aCols[nA])]  // se o item nao estiver deletado
				If (aProdOrig[nA][1] == aCols[nA][nPosItem]) .AND. (aProdOrig[nA][2] == aCols[nA][nPosProduto] ) .AND. ;
					(aProdOrig[nA][3] <> aCols[nA][nPosEntr])
					If aCols[nA][nPosEntr] == "2"
						If !lAutoExec
							Alert(STR0216) //Tipo de reserva só pode ser 1 ou 3
						Else
							Conout(STR0216) //Tipo de reserva só pode ser 1 ou 3
							Help( " ", 1, "Help",, STR0216, 1, 0 )
						Endif
						lRet := .F.
						Exit
					EndIf
				EndIf
				AADD(aNovProd,{aCols[nA][nPosItem],aCols[nA][nPosProduto] ,aCols[nA][nPosEntr],aProdOrig[nA][4]})
			EndIf
		Next nA
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Se o array estiver vazio e porque nao houve alteracao de produtos        ³
// ou operacao não permitida(lRet), sai da funcao                           ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If !Len(aNovProd) > 0 .OR. !lRet
	Return(.F.)
EndIf

For nA := 1 To Len(aNovProd)

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Se o novo produto for do tipo 3 vai fazer a funcao abaixo do Lj7Pedido() ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If aNovProd[nA][3] == "3"
		Begin Transaction

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Posiciona no item pai que vai ser alterado                               ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		DbSelectArea("SL2")
		DbSetOrder(1) //L2_FILIAL+L2_NUM+L2_ITEM+L2_PRODUTO
		If DbSeek(xFilial("SL2")+cOrcamento+aNovProd[nA][1]+aNovProd[nA][2])

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Deletando as informacoes dos itens do pedido filho apatir do pai         ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			cFilialOri := SL2->L2_FILRES
			cOrcOri    := SL2->L2_ORCRES
			DbSelectArea("SL2")
			DbSetOrder(1)//L2_FILIAL+L2_NUM+L2_ITEM+L2_PRODUTO
			If DbSeek(cFilialOri+cOrcOri)
				RecLock("SL2",.F.)
				DbDelete()
				MsUnLock()
				DbCommit()
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Array para controlar os itens dos pedidos ja excluidos                   ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				If aScan(aSl1Del,(cFilialOri+cOrcOri)) == 0
					AADD(aSl1Del,{(cFilialOri+cOrcOri)})
				EndIf

			EndIf
		EndIf


		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Alterando o tipo de entrega do item do pai apatir do filho               ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		DbSelectArea("SL2")
		DbSetOrder(1) //L2_FILIAL+L2_NUM+L2_ITEM+L2_PRODUTO
		If DbSeek(xFilial("SL2")+cOrcamento+aNovProd[nA][1]+aNovProd[nA][2])
			RecLock("SL2",.F.)
			REPLACE SL2->L2_ENTREGA WITH aNovProd[nA][3]
			MsUnLock()
			DbCommit()
		EndIf

		End Transaction

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Finaliza o arquivo criado para bloqueio de edicao da venda				³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
 		Lj7XSL1('D')
	Else

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Tabela Orcamento: carrega na variavel o numero do pedido					³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		DbSelectArea("SL2")
		DbSetOrder(1) //L2_FILIAL+L2_NUM+L2_ITEM+L2_PRODUTO
		If DbSeek(xFilial("SL2")+cOrcamento+aNovProd[nA][1]+aNovProd[nA][2])
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Deletando as informacoes dos itens do pedido filho apatir do pai         ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			cFilialOri := SL2->L2_FILRES
			cOrcOri    := SL2->L2_ORCRES
			DbSelectArea("SL2")
			DbSetOrder(1)///L2_FILIAL+L2_NUM
			If DbSeek(cFilialOri+cOrcOri)
				cReserva := AllTrim(SL2->L2_RESERVA)
				cPedido  := AllTrim(SL2->L2_PEDRES)

				RecLock("SL2",.F.)
				DbDelete()
				MsUnLock()
				DbCommit()
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Array para controlar os itens dos pedidos ja excluidos                   ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				If aScan(aSl1Del,(cFilialOri+cOrcOri)) == 0
					AADD(aSl1Del,{(cFilialOri+cOrcOri)})
				EndIf
			EndIf

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Posiciona no SL2 PAI para funcao Lj7Pedido(), para gerar o ped. novamente³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			DbSelectArea("SL2")
			DbSetOrder(1) //L2_FILIAL+L2_NUM+L2_ITEM+L2_PRODUTO
			DbSeek(xFilial("SL2")+cOrcamento+aNovProd[nA][1]+aNovProd[nA][2])
		EndIf

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Tabela Pedido de Venda: posiciona no registro para funcao Lj7Pedido()	³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		DbSelectArea("SC5")
		DbSetOrder(1) //C5_FILIAL+C5_NUM
		If DbSeek(cFilialOri+cPedido)

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Tabela Itens Pedido de Venda: posiciona no registro para funcao Lj7Pedido()³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			DbSelectArea("SC6")
			DbSetOrder(1) //C6_FILIAL+C6_NUM
			If DbSeek(cFilialOri+cPedido)

				Begin Transaction

				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Faz bkp da filial atual.                   ³
				//³Carrega a Filial com a filial do Ped. Filho³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				cBkpFilial := cFilAnt
				cFilAnt    := cFilialOri

				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Estorna Liberação³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				DbSelectArea("SC9")
				DbSetOrder(1) //C9_FILIAL+C9_PEDIDO
				If DbSeek(cFilialOri+SC5->C5_NUM)
					While  !Eof() .AND. SC9->C9_PEDIDO == SC5->C5_NUM
						aArea      := GetArea()
						a460Estorna()
						RestArea(aArea)
						DbSkip()
					End
				EndIf

				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Elimina Residuo³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				DbSelectArea("SC6")
				DbSetOrder(1) //C6_FILIAL+C6_NUM
				If DbSeek(cFilialOri+SC5->C5_NUM)
					While (!Eof() .AND. cFilialOri == SC6->C6_FILIAL .AND. SC6->C6_NUM == SC5->C5_NUM)
						aArea := GetArea()
						MaResDoFat(nil, .T., .F.,)
						MaLiberOk({ SC5->C5_NUM }, .T.)
						RestArea(aArea)
						DbSkip()
					End
				EndIf


				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Carrega a Filial correta que foi salva no BKP³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				cFilAnt    := cBkpFilial

				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Semafaro para fechamento de orcamentos filhos Elimina Residuo  ³
				//³A existencia aqui, pois quando elimia residuo esta na filial   ³
				//³de criacao do orçamento, não fechando o arquivo AUTOCOM        ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				Lj7XSL1('D')

				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Tabela Itens do Orc: deletar os itens do orc alterado                    ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				DbSelectArea("SL2")
				DbSetOrder(1) //L2_FILIAL+L2_NUM+L2_ITEM+L2_PRODUTO
				If DbSeek(cFilialOri+cOrcOri)
					RecLock("SL2",.F.)
					DbDelete()
					MsUnLock()
					DbCommit()
				EndIf

				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Alterando o tipo de entrega do item do pai apatir do filho               ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				DbSelectArea("SL2")
				DbSetOrder(1) //L2_FILIAL+L2_NUM+L2_ITEM+L2_PRODUTO
				If DbSeek(xFilial("SL2")+cOrcamento)
					While !Eof() .AND. SL2->L2_NUM == cOrcamento
						If SL2->L2_PRODUTO == aNovProd[nA][2] .AND. SL2->L2_QUANT == aNovProd[nA][4]
							RecLock("SL2",.F.)
							REPLACE SL2->L2_ENTREGA WITH aNovProd[nA][3]
							MsUnLock()
							DbCommit()
						EndIf
						DbSkip()
					End
				EndIf

				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Tabela Reserva: restaura o registro para reserva                         ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				DbSelectArea("SC0")

				SET DELETE OFF

				DbSetOrder(1) //C0_FILIAL+C0_NUM
				If DbSeek(cOrcamento+cReserva)
					While !Eof() .AND. SC0->C0_NUM == cReserva
						If SC0->C0_PRODUTO == aNovProd[nA][2] .AND. SC0->C0_QUANT == aNovProd[nA][4]
							RecLock("SC0",.F.)
							DbRecall()
							MsUnLock()
							DbCommit()
						EndIf
						DbSkip()
					End

				EndIf

				SET DELETE ON

				End Transaction
			EndIf
		EndIf
	EndIf
Next nA

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Deletando as informacoes do pedido filho                                 ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Begin Transaction
For nA := 1 To Len(aSl1Del)
	DbSelectArea("SL1")
	DbSetOrder(1) //L1_FILIAL+L1_NUM
	If DbSeek(aSl1Del[nA][1])
		RecLock("SL1",.F.)
		DbDelete()
		MsUnLock()
		DbCommit()
	EndIf
Next nA
End Transaction

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Adciona no array somente os itens alt. para gerar ped. correto           ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
DbSelectArea("SL2")
DbSetOrder(1) //L2_FILIAL+L2_NUM+L2_ITEM+L2_PRODUTO
If DbSeek(xFilial("SL2")+cOrcamento)
	For nA := 1 To Len(aNovProd)
		While !Eof() .AND. SL2->L2_NUM == cOrcamento
			If SL2->L2_PRODUTO == aNovProd[nA][2] .AND. SL2->L2_QUANT == aNovProd[nA][4]
				AADD(aProdPed,{SL2->L2_ITEM, SL2->L2_PRODUTO})
			EndIf
			DbSkip()
		End
	Next nA
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Posiciona no registro pai que vai gerar o pedido pela Funcao Lj7Pedido() ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
DbSelectArea("SL1")
DbSetOrder(1) //L1_FILIAL+L1_NUM
If DbSeek(xFilial("SL1")+cOrcamento)
	If Len(aProdPed) > 0
		Lj7Pedido({},2,NIL,.F.,{},.F.,,,.T.,aProdPed)
	Else
		return(.F.)
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Apartir de agora tudo que for feito e nã será mais alteracao de orçametno³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
lAlterOrc := .F.

Return (.T.)

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³Lj7ValidAt ³ Autor ³Vendas CRM            ³ Data ³ 04/03/11 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Validacao ser poder ser feito alteracao                 	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ ExpL1:= Lj7ValidAt()                                       ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ Nil														  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Retorno	 ³ Logico. Se permite ou nao fazer alteracao no pedido.       ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ SIGALOJA													  ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/

Function Lj7ValidAt()
Local lParam   	 := (SuperGetMV("MV_LJCHGTP",,2) == 1 .AND. SuperGetMV("MV_LJALTEN", NIL, .F.))	// Verificacao dos parametros de alteracao
Local cOrcamento := SL1->L1_NUM         // Numero do orcamento
Local aPedFilho  := {}                  // Dados do pedido filho
Local nA         := 0                   // Auxiliar
Local aAreaSL1   := {}					// Array para gravacao da Area

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Validacao se pode ser alterado o orcamento                  ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If !lParam
	Alert(STR0213) //Este campo não pode ser alterado. Verificar os parametros para habilitar esta função
	Return(.F.)
EndIf

aProdOrig  := {}
aPedFilho  := {}

DbSelectArea("SL1")
DbSetOrder(1) //L1_FILIAL+L1_NUM
If DbSeek(xFilial("SL1")+cOrcamento)

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Validacao se o orcamento e filho ou pai                     ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If !Empty(AllTrim(SL1->L1_FILRES)) .AND.  !Empty(AllTrim(SL1->L1_ORCRES))
		If !lAutoExec
			Alert(STR0228 + " " + STR0229 + " : " +SL1->L1_FILRES + ' - ' + SL1->L1_ORCRES)
		Else
			Conout(STR0228 + " " + STR0229 + " : " +SL1->L1_FILRES + ' - ' + SL1->L1_ORCRES)
			Help( " ", 1, "Help",, STR0228 + " " + STR0229 + " : " +SL1->L1_FILRES + ' - ' + SL1->L1_ORCRES, 1, 0 )
		Endif
		//STR0228 - Alteração permitida, somente para orçametno pai.
		//STR0229 -  Alteração de ser feita em (FILIAL - OCAMENTO)
		Return(.F.)
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Identificacao dos dados do orc. filho                       ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	aAreaSL1 := SL1->(GetArea())
	DbSelectArea("SL1")
	DbSetOrder(14)
	If DbSeek(xFilial("SL1")+cOrcamento)
    	While !Eof() .And. SL1->L1_ORCRES == cOrcamento
			AADD(aPedFilho,{SL1->L1_FILIAL, SL1->L1_NUM})
			DbSkip()
    	End
	EndIf
	RestArea(aAreaSL1)
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Validacao se o orc. filho ja foi finalizado com venda       ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If Len(aPedFilho)  > 0
   		For nA := 1 To Len(aPedFilho)
   			DbSelectArea("SL1")
	       	DbSetOrder(1)//L1_FILIAL+L1_NUM
    	   	If DbSeek(aPedFilho[nA][1]+aPedFilho[nA][2])//FILIAL + ORCAMENTO
       			While !Eof() .AND. (SL1->L1_NUM == aPedFilho[nA][2])
					If !Empty(AllTrim(SL1->L1_DOC)) .AND. !Empty(AllTrim(SL1->L1_SERIE)) .AND. ;
						 !Empty(AllTrim(SL1->L1_DOCPED)) .AND. !Empty(AllTrim(SL1->L1_SERPED))
						If !lAutoExec
							Alert(STR0214)
						Else
							Conout(STR0214)
							Help( " ", 1, "Help",, STR0214, 1, 0 )
						Endif
						Return(.F.)
					EndIf
					DbSkip()
        		End
        	EndIf

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Validacao se existe venda para os itens do filho³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
        	DbSelectArea("SL2")
        	DbSetOrder(1) //L2_FILIAL+L2_NUM
        	If DbSeek(aPedFilho[nA][1]+aPedFilho[nA][2])
        		If SL2->L2_ENTREGA == '3' .Or. SL2->L2_ENTREGA == '4' //3=Entrega; 4=Retira Posterior c/ Nota
	       			While !Eof() .AND. (SL2->L2_NUM == aPedFilho[nA][2])
						//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
						//³Tabela Pedido de Venda: posiciona no registro para funcao Lj7Pedido()	³
						//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
						DbSelectArea("SC5")
						DbSetOrder(1) //C5_FILIAL+C5_NUM
						If DbSeek(aPedFilho[nA][1]+SL2->L2_PEDRES)
							If !Empty(AllTrim(SC5->C5_NOTA)) .AND. !Empty(AllTrim(SC5->C5_SERIE))
								If !lAutoExec
									Alert(STR0214) //Pedido já gerado como venda, impossivel ser alterado
								Else
									Conout(STR0214) //Pedido já gerado como venda, impossivel ser alterado
									Help( " ", 1, "Help",, STR0214, 1, 0 )
								Endif
								Return(.F.)
							EndIf
						EndIf
						//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
						//³Tabela Reserva: restaura o registro para reserva                         ³
						//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
						DbSelectArea("SC0")
						SET DELETE OFF
						DbSetOrder(1) //C0_FILIAL+C0_NUM
						If !DbSeek(aPedFilho[nA][1]+SL2->L2_RESERVA)
							If !lAutoExec
								Alert(STR0215) //Reserva de produto não encontrada, não será permitida alteração
							Else
								Conout(STR0215) //Reserva de produto não encontrada, não será permitida alteração
								Help( " ", 1, "Help",, STR0215, 1, 0 )
							Endif
							Return(.F.)
						EndIf
						SET DELETE ON
						SL2->(DbSkip())
	        		End
	       		EndIf
        	EndIf
		Next nA
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Adiciona no array as inf. originas de entrega de cada item  ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	DbSelectArea("SL2")
	DbSetOrder(1) //L2_FILIAL+L2_NUM
	If DbSeek(xFilial("SL2")+cOrcamento)
		While !Eof() .AND. SL2->L2_FILIAL+SL2->L2_NUM == xFilial("SL2")+cOrcamento
			AADD(aProdOrig, {SL2->L2_ITEM, SL2->L2_PRODUTO, SL2->L2_ENTREGA, SL2->L2_QUANT})
			DbSkip()
		End
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Posiciona no SL1 e SL2 do PAI do Orc.³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	DbSelectArea("SL1")
	DbSetOrder(1) //L1_FILIAL+L1_NUM
	DbSeek(xFilial("SL1")+cOrcamento)

	DbSelectArea("SL2")
	DbSetOrder(1) //L2_FILIAL+L2_NUM
	DbSeek(xFilial("SL2")+cOrcamento)
EndIf

Return (.T.)


/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³LjGRecFo   ³ Autor ³ Vendas CRM		    ³ Data ³ 02/05/11 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Retorna o RECNO da especie de documento fiscal selecionada ³±±
±±³			 ³ no inicio da venda (SFP) - F1CHI                           ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ ExpN1:= LjGRecFo()                                         ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ Nil														  ³±±
±±³          ³ 															  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Retorno	 ³ ExpN1 - Numero do RECNO posicionado na tabela SFP.		  ³±±
±±³          ³                                     						  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701 													  ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/

Function LjGRecFo ()

Local nRecno := nRecnoFo	//Obter da variavel estatica o RECNO da tabela de controle de formularios (SFP)

Return nRecno

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³LjDatFon  	  ºAutor  ³Vendas Clientes º Data ³  18/02/2011 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Verifica a data dos fontes para poder executas novas funcoes º±±
±±º          ³ da lib.                                      				º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ Loja701                                                      º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function LjDatFon()
Local lRet := .F.

If GetAPOInfo("MSGETDAD.PRW")[4] >= CTOD("17/12/2010") .AND. ;
   GetAPOInfo("APLIB170.PRW")[4] >= CTOD("18/01/2011") .AND. ;
   GetAPOInfo("MsGetDB.prw")[4] >= CTOD("24/01/2011")

	lRet := .T.
EndIf

Return lRet

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7BtnLista     ºAutor  ³Vendas Clientes º Data ³  18/02/2011 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Rotina que apresenta a consulta da lista de presentes	    º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ Loja701                                                      º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/

Static Function Lj7BtnLista()

Local aProdLista	:= {}				   					//Array contendo todos os produtos selecionados pelo usuario para compra da lista
Local aArea		:= GetArea()		   					//Salva a Area Atual
Local nItensSel	:= 0				   					//Variavel de controle do laco
Local nTamCols	:= Len(aCols)		   					//Busca o tamanho do aCols
Local aItemLst	:= {}				   					//Itens de Lista que ja constam no aCols
Local nSeqCols	:= 0 									//Sequencia do aCols no laco
Local cTpOper		:= SuperGetMV("MV_LJLPTIV",,"")			//Tipo da Operacao para o Pedido de Venda (TES Inteligente)
Local cTESPad		:= SuperGetMV("MV_LJLPTSV",,"")			//TES padrao para o Pedido de Venda

//Variaveis de posicao do aCols e aColsDet
Local nPosProd	:= aScan(aHeader,{|x| Alltrim( Upper(x[2]) ) == "LR_PRODUTO"})			//Posicao do campo de codigo de produto
Local nPosLista	:= aScan(aHeader,{|x| Alltrim( Upper(x[2]) ) == "LR_CODLPRE"})			//Posicao do campo codigo da lista de presente
Local nPosItLista	:= aScan(aHeader,{|x| Alltrim( Upper(x[2]) ) == "LR_ITLPRE" })			//posicao do campo item da lista de presente
Local nPosEntrega	:= aScan(aHeader,{|x| Alltrim( Upper(x[2]) ) == "LR_ENTREGA"})			//posicao do campo tipo de entrega
Local nPosQuant	:= aScan(aHeader,{|x| Alltrim( Upper(x[2]) ) == "LR_QUANT"	 })			//posicao do campo quantidade
Local nPosReserva	:= aScan(aHeaderDet,{|x| Alltrim(Upper(x[2])) == "LR_RESERVA"})	//Posicao do campo Codigo da Reserva
Local nPosTES		:= aScan(aHeaderDet,{|x| Alltrim(Upper(x[2])) == "LR_TES"})		//Posicao do campo codigo do TES
Local nPosMsmLPre	:= aScan(aHeader,{|x| Alltrim( Upper(x[2]) ) == "LR_MSMLPRE"})			//Codigo da mensagem do Comprador
Local nPosMsgLPre	:= aScan(aHeader,{|x| Alltrim( Upper(x[2]) ) == "LR_MSGLPRE"})			//Mensagem do Comprador
Local nPosRemLPre	:= aScan(aHeader,{|x| Alltrim( Upper(x[2]) ) == "LR_REMLPRE"})			//Codigo da mensagem do Remetente
Local nPosRevLPre	:= aScan(aHeader,{|x| Alltrim( Upper(x[2]) ) == "LR_REVLPRE"})			//Mensagem do Remetente
Local nPosDtLocal	:= aScan(aHeaderDet,{|x| Alltrim(Upper(x[2])) == "LR_LOCAL"})				// Posicao do local (armazem)
Local aBkCols		:= {}

If nPosLista == 0 .OR. nPosItLista == 0 .OR. nPosEntrega == 0
	If !lAutoExec
		MsgInfo(STR0217)   //// "Para a utilizacao da lista os campos LR_CODLPRE, LR_ITLPRE e LR_ENTREGA tem que estar como usados"
	Else
		Conout(STR0217)   //// "Para a utilizacao da lista os campos LR_CODLPRE, LR_ITLPRE e LR_ENTREGA tem que estar como usados"
		Help( " ", 1, "Help",, STR0217, 1, 0 )
	Endif
	Return
EndIf

If nPosMsmLPre == 0 .OR. nPosMsgLPre == 0 .OR. nPosRemLPre == 0 .OR. nPosRevLPre == 0
	If lAutoExec .OR. (!lAutoExec .AND. Aviso(STR0218,STR0219,{STR0220,STR0221},2) == 2)   /////"Lista de Presentes","Os campos de Mensagem da Lista de Presente nao estao visuais, continua o processo mesmo assim?"   {"Sim","Nao"}
		Return
	EndIf
EndIf

For nSeqCols := 1 to nTamCols
	If !Empty(aCols[nSeqCols][nPosLista])
		aAdd(aItemLst,{	aCols[nSeqCols][nPosLista],;		//Codigo da Lista
						aCols[nSeqCols][nPosItLista],;		//Item do Codigo da Lista
						aCols[nSeqCols][nPosQuant]})		//Quantidade do Item
	EndIf
Next nSeqCols

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Rotina para consulta de Listas de Presentes.                      ³
//³Parametros referente a Funcao Loja845.                            ³
//³Exp01[N] : Comportamento rotina 1.Busca + Edicao 2.Busca + Retorno³
//³Exp02[N] : Disp.modo 2 define estrutura retorno de dados :        ³
//³           1.Cabecalho 2.Itens 3.Cabecalho + Itens                ³
//³Exp03[C] : Determinar o tipo de lista sera pesquisado (ME1_TIPO)  ³
//³Exp04[C] : Numero da lista                                        ³
//³		      Modo 2 + Retorno 1 : retorno dados cab. sem interface  ³
//³           Modo 2 + Retorno 2|3 : abrir componente sel.produtos   ³
//³Exp05[L] : Determina se a pesquisa eh online ou por webservice    ³
//³Exp06[L] : Abrir interface de digitacao de nomes                  ³
//³Exp07[L] : Enviar mensagem aos atores (protagonistas)             ³
//³Exp08[L] : Listar apenas itens com quantidade em aberto           ³
//³Exp09[C] : Origem a ser considerado para os itens                 ³
//³Exp10[C] : Filtro ME2                                             ³
//³Exp11[C] : Multi-selecao                                          ³
//³Exp12[C] : Marcar todos                                           ³
//³Exp13[C] : Quantidade utilizada                                   ³
//³Exp14[C] : Permite alterar quantidade?                            ³
//³Exp15[C] : Permite alterar modo de entrega?                       ³
//³Exp16[C] : Tipo de evento que a rotina devera pesquisar           ³
//³Exp17[C] : Status da lista 1.Ativa 2.Inativa                      ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
aProdLista	:= 	Loja845(2		,3			,NIL		,NIL		,;
						.T.		,.T.		,.T.		,.T.		,;
						NIL		,NIL		,.T.		,.T.		,;
						aItemLst,.T.		,.T.		,NIL		,;
						1		)

//----------------------------------------------------------------------------//
// Verifica se o cliente é o Dono do Envento  ( criador da lista de presentes ) //
//----------------------------------------------------------------------------//
If M->LQ_CLIENTE == ME1->ME1_CODCLI
	MsgAlert(STR0353)//Venda não permitida. O cliente é o Dono do Evento da Lista de Presentes.
Else

	//Verifico se o retorno foi o array
	If ValType(aProdLista) == "A"
		//Percorro todos os itens que foram selecionados pelo usuario
		For nItensSel	:= 1 to Len(aProdLista[2])

			//Verifico se o ultimo item do aCols esta preenchido ou se esta deletado, nesse caso incluo uma linha nova
			If !Empty(aCols[nTamCols,nPosProd]) .OR. aTail(aCols[nTamCols])
				Eval(oGetVA:oBrowse:bAdd)
				nTamCols:= Len(aCols)
			EndIf

			aBkCols := aClone(aCols)

			//Atualizo a variavel de memoria e o acols com o codigo do produto selecionado
			M->LR_PRODUTO				:= aProdLista[2][nItensSel][2]
			aCols[nTamCols,nPosProd]	:= aProdLista[2][nItensSel][2]
			aCols[nTamCols,nPosLista]	:= aProdLista[1][1]
			aCols[nTamCols,nPosItLista]	:= aProdLista[2][nItensSel][1]
			aCols[nTamCols,nPosEntrega]	:= IIF(aProdLista[1][2]== "4","2","3")	//1=Retira Posterior;2=Retira;3=Entrega
			aCols[nTamCols,nPosQuant]	:= aProdLista[2][nItensSel][4]

			//Caso os campos de mensagem estejam visuais atualiza.
			If nPosMsmLPre > 0 .AND. nPosMsgLPre > 0 .AND. nPosRemLPre > 0 .AND. nPosRevLPre > 0
				aCols[nTamCols,nPosMsgLPre]	:= aProdLista[2][nItensSel][7]		//Mensagem do Comprador
				aCols[nTamCols,nPosRevLPre]	:= aProdLista[2][nItensSel][6]		//Mensagem do Remetente
			EndIf

			//Chamo a rotina que efetua todas as validacoes do campo de produto
			If LJ7PROD(.T.)

				//Coloca "S" no campo de codigo da reserva para tratar no LjGrvTudo
				If aCols[nTamCols,nPosEntrega] == "3" .AND. nPosReserva > 0	.AND. Len(aColsDet) >= nTamCols	//Entrega
					aColsDet[nTamCols,nPosReserva]:= "S"
				EndIf

				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Atualiza o local do produto se estiver fazio.         ³
				//³Motivo: Existe validacoes no LOJA701 sendo o          ³
				//³produto digitado pelo campo LR_PRODUTO. Neste caso da ³
				//³lista, nunca sera atraves deste campo.                ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				If Empty(aColsDet[nTamCols][nPosDtLocal])
					aColsDet[nTamCols][nPosDtLocal]	    := RetFldProd(aCols[nTamCols,nPosProd],"B1_LOCPAD")
				EndIf

				//Atualizo o TES de acordo com os parametros para Tipo de Operacao e TES
				If nPosTES > 0 .AND. Len(aColsDet) >= nTamCols .AND. (!Empty(cTpOper) .OR. !Empty(cTESPad))
					//Caso o parametro do tipo de operacao esteja preenchido busco por ele
					If !Empty(cTpOper)
						cTESPad := MaTESInt(2,cTpOper,M->LQ_CLIENTE,M->LQ_LOJA,"C",M->LR_PRODUTO)
					EndIf
					//Caso o TES retornado pelo TES inteligente ou pelo parametro de TES seja diferente do contido no aColsDet
					If cTESPad <> aColsDet[nTamCols,nPosTES] .AND. !Empty(cTESPad)
						aColsDet[nTamCols,nPosTES]	:= cTESPad
						M->LR_TES					:= cTESPad
						LJ7ALTCF()
					EndIf
				EndIf
			Else
				aCols := aClone(aBkCols)
				Exit
			EndIf

		Next nItensSel
		oGetVA:Refresh()
	EndIf
EndIf
Return


/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7Call003	  ºAutor  ³Vendas Clientes º Data ³  22/11/2011 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Chamadas de funcoes validadoras da delecao do item			º±±
±±º          ³ Validacao de modulos, P.E e Templates						º±±
±±ºParametro ³                              								º±±
±±º          ³ nPosItem = posicao do codigo do item no aCols				º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ Loja701                                                      º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7Call003(nPositem)
Local lRet := .T.	// Retorno da funcao

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Chamada da funcao LJ7003 para Fidelizacao (CRDXFUNE)           ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If FindFunction("LJ7003()")
	lRet := LJ7003(.F.,.F.)
	If ValType( lRet ) <> "L"
		lRet := .T.
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Ponto de Entrada de Templates para validar a delecao do item   ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If ExistTemplate("LJ7003")
	lRet := ExecTemplate("LJ7003",.F.,.F.,{lRet, aCols[n][nPositem]})
	If ValType( lRet ) <> "L"
		lRet := .T.
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Ponto de entrada para validar a delecao do item                ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If ExistBlock("LJ7003")
	lRet := ExecBlock("LJ7003",.F.,.F.,{lRet, aCols[n][nPositem] })
	If ValType( lRet ) <> "L"
		lRet := .T.
	EndIf
EndIf
Return lRet
/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7EndSer3	  ºAutor  ³Vendas Clientes º Data ³  22/11/2011 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Libera Cont de Enderecamento para Serie 3 no Loja			º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametro ³                              								º±±
±±º          ³ 																º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ Loja701                                                      º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7EndSer3()

Local lRet := .T.	// foi mantida a funcao por ser chamada de outros lugares ,
 					// mas antes era verificado o getrporelase("R7") para retornar
 					// .T.
Return(lRet)

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Fun‡„o    ³AjustaHelp    ³ Autor ³Vendas CRM            ³ Data ³26.01.2011³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descri‡„o ³Ajusta os helps                                                ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³AjustaHelp()                                                   ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³Nenhum                                                         ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Retorno   ³Nenhum                                                         ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
*/
Static Function AjustaHelp()
Local aArea 	:= GetArea()
Local aHelpPor	:= {}
Local aHelpEng	:= {}
Local aHelpSpa	:= {}

aHelpPor :=	{"Venda não pode ser finalizada devido","orçamento já estar vencido."}
aHelpSpa :=	{"Venda não pode ser finalizada devido","orçamento já estar vencido."}
aHelpEng :=	{"Venda não pode ser finalizada devido","orçamento já estar vencido."}
PutHelp("PDTVENCIDO",aHelpPor,aHelpEng,aHelpSpa,.F.)

aHelpPor :=	{"Selecione um orçamento válido."}
aHelpSpa :=	{"Selecione um orçamento válido."}
aHelpEng := {"Selecione um orçamento válido."}
PutHelp("SDTVENCIDO",aHelpPor,aHelpEng,aHelpSpa,.F.)

aHelpPor := {}
aHelpEng := {}
aHelpSpa := {}

aHelpPor :=	{"Ocorreu um erro ao recuperar a série","do pedido, verificar o parâmetro da","série: MV_LOJAPED. O pedido não será","gravado."}
aHelpSpa :=	{"Ocorreu um erro ao recuperar a série","do pedido, verificar o parâmetro da","série: MV_LOJAPED. O pedido não será","gravado."}
aHelpEng :=	{"Ocorreu um erro ao recuperar a série","do pedido, verificar o parâmetro da","série: MV_LOJAPED. O pedido não será","gravado."}
PutHelp("PSERIEPEDIDO",aHelpPor,aHelpEng,aHelpSpa,.T.)

aHelpPor :=	{"A série informada no parâmetro deverá","existir na Tabela 01 do SX5. Informe o","Administrador do Sistema sobre este erro."}
aHelpSpa :=	{"A série informada no parâmetro deverá","existir na Tabela 01 do SX5. Informe o","Administrador do Sistema sobre este erro."}
aHelpEng := {"A série informada no parâmetro deverá","existir na Tabela 01 do SX5. Informe o","Administrador do Sistema sobre este erro."}
PutHelp("SSERIEPEDIDO",aHelpPor,aHelpEng,aHelpSpa,.T.)
RestArea(aArea)

Return

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³LjGetCancel	  ºAutor  ³Vendas Clientes º Data ³  18/01/2011 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Determina se sera permitido selecionar o botao cancelar da	º±±
±±º          ³ tela do objeto Getadados passado como parametro.				º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametro ³                              								º±±
±±º          ³ oGet = Getdados dos itens do orcamento						º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ Loja701                                                      º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function LjGetCancel(oGet)
Local lRet 			:= .T.
Local cMsg 			:= STR0204 + CRLF + STR0205 //"Operação inválida!" //"Para excluir, primeiro confirme o item e depois utilize a tecla delete para realizar a exclusão."
Local nLRRESERVA	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_RESERVA"})			// Posicao do codigo da reserva
Local nPosProd		:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_PRODUTO"})			// Posicao do codigo do produto
Local lVAssConc    	:= LjVassConc()				// Indica se o cliente utiliza a Vda Assistida Concomitante
Local cCampo 		:= ""
Local cCmpTitulo 	:= ""
Local xValorAnt		:= Nil
Local nOrderSX3		:= 0
Local nRecnoSX3		:= 0

If nLRRESERVA > 0 .And. Len(aColsDet) >= n .And. !Empty(aColsDet[n][nLRRESERVA])
	cCampo 		:= Replace(Readvar(), "M->", "")
	xValorAnt 	:= GDFieldGet(cCampo)
	If &(ReadVar()) != xValorAnt //Verifica se o conteudo do campo foi alterado

		//Guarda posicionamento do SX3
		nOrderSX3 := SX3->( IndexOrd() )
		nRecnoSX3 := SX3->( Recno() )

		//Posiciona no campo no SX3 para poder pegar o titulo atraves da funcao X3Titulo()
		SX3->( DbSetOrder(2) )
		SX3->( DbSeek(cCampo) )
		cCmpTitulo := AllTrim(X3Titulo())

		//Recupera o posicionamento anterior no SX3
		SX3->( DbSetOrder(nOrderSX3) )
		SX3->( DbGoTo(nRecnoSX3) )

		cMsg := STR0326 + CRLF + STR0327 + Upper(cCmpTitulo) + STR0328 + AllTrim(cValToChar(xValorAnt)) //"Já existe uma reserva para esse produto, não é possível ser alterado." ### "Para fechar essa tela, retorne o valor anterior no campo " ### " para: "
		lRet := .F.
	EndIf
EndIf

If nPosProd > 0 .AND. lRet .AND. Len(aCols) >= n .AND. !Empty(aCols[n][nPosProd])
	If lVAssConc .And. !lIsPafNfce
  		cMsg := STR0348+CRLF+STR0349//"O Item já foi registrado na impressora !" + "Para cancela-lo é necessário confirmar essa tela e depois pressionar DELETE no item."
 	Else
  		cMsg := STR0377+CRLF+STR0349//"O Item já foi registrado!" + "Para cancela-lo é necessário confirmar essa tela e depois pressionar DELETE no item."
 	EndIf
 	
 	If !lIsPafNfce
 		lRet := .F.
 	EndIf
EndIf

If !lRet
	Alert( cMsg )
	lRet := .F.
EndIf

Return lRet


/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7FSLAn	      ºAutor  ³Vendas Clientes º Data ³  06/03/2012 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Libera a analise de credito que esta off-line ou na mesa     º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametro ³                              											 º±±
±±º          ³ 																				 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ Loja701                                                      º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7FSLAn()

Local oLjIntFSAn := nil// Instancia o objeto de integração com o financial Service - Orçamento

If  !IsCaixaLoja( xNumCaixa() )
	Aviso( STR0056, STR0057 + Alltrim(cUserName) + ;  //"Atenção" ### "O usuário "
	STR0260, {STR0028} )  //	" não pode fazer liberação manual da análise de crédito. Utilize a opção Senhas/Caixas no Menu Miscelânea para incluir um Caixa. Caso já exista um cadastrado, re-entre no sistema com uma senha de Caixa." ### "Ok"
Else
	oLjIntFSAn := LjClInFSAn():New(SL1->L1_FILIAL, SL1->L1_NUM)
	oLjIntFSAn:AprovarAna()
	FreeObj(oLjIntFSAn)
	oLjIntFSAn := nil
EndIf

Return

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7FSRAn	      ºAutor  ³Vendas Clientes º Data ³  06/03/12   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Re-envia a analise de credito reprovada para a mesa	     	º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametro ³                              								º±±
±±º          ³ 																º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ Loja701                                                      º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
*/
Function Lj7FSRAn()
Local oLjIntFSAn := nil // Instancia o objeto de integração com o financial Service - Orçamento

If  !IsCaixaLoja( xNumCaixa() )
	Aviso( STR0056, STR0057 + Alltrim(cUserName) + ;  //"Atenção" ### "O usuário "
			STR0261, {STR0028} )  //" não pode fazer re-envio da análise de crédito. Utilize a opção Senhas/Caixas no Menu Miscelânea para incluir um Caixa. Caso já exista um cadastrado, re-entre no sistema com uma senha de Caixa." ### "Ok"
Else
	oLjIntFSAn := LjClInFSAn():New(SL1->L1_FILIAL, SL1->L1_NUM)
	oLjIntFSAn:ReEnviarAna()

	FreeObj(oLjIntFSAn)
	oLjIntFSAn := nil


EndIf

Return

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7RCLoad ºAutor  ³ Vendas Cliente     º Data ³  07/07/2012 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Carrega as variaveis estaticas referente a "Recarga de     º±±
±±º          ³ Celular".                                                  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ SIGALOJA - Recarga de Celular                              º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function Lj7RCLoad()

If !IsBlind()
	lRCAtiva	:= lUsaTef .And. SubStr(LjGetStation("REDES"),3,1) == "1"	// Verifica se o campo LG_REDES esta configurado com "Recarga de Celular" ativa.
	lRCAtiva  	:= lRCAtiva .And. LjGetStation("TIPTEF") == TEF_CLISITEF	// Soh ativa a "Recarga de Celular" se o Tipo do TEF configurado no cadastro de estacao for modalidade CliSitef.
	cMVLJPREC	:= SuperGetMv("MV_LJPREC", ,"" )  							// Parametro com o codigo do(s) produto(s) definido(s) como "Recarga de Celular".
	aProdRcg   	:= StrToKarr(cMVLJPREC , "/")								// Array com a relacao de produtos definidos como "Recarga de Celular".
	aRegTefRC 	:= {}
	lRecarEfet	:= .F.
Else
	lRCAtiva 	:= .F. //Se a conexao efetuada com o Protheus nao possui interface com o usuario, considera desativada a "Recarga de Celular"
EndIf

Return Nil

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7RCPrdRCºAutor  ³ Vendas Cliente     º Data ³  07/07/2012 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Verifica se o produto informado eh "Recarga de Celular".   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ SIGALOJA - Recarga de Celular                              º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7RCPrdRC(cCodProdut)
Return ( Ascan( aProdRcg, {|x| AllTrim(x) == AllTrim(cCodProdut)} ) > 0 )


/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7RCAtivaºAutor  ³ Vendas Cliente     º Data ³  07/07/2012 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Verifica se a configuracao de "Recarga de Celular" estah   º±±
±±º          ³ ativa.                                                     º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ SIGALOJA - Recarga de Celular                              º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7RCAtiva()
Return lRCAtiva

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma ³Lj7RCStatusºAutor  ³ Vendas Cliente     º Data ³  07/07/2012 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Verifica ou atualiza o status da "Recarga de Celular".     º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ SIGALOJA - Recarga de Celular                              º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7RCStatus(lNewStatus)
If lNewStatus <> Nil
	lRecarEfet := lNewStatus
	If !lNewStatus //Cancelamento da Recarga
		aRegTefRC := {}
	EndIf
EndIf
Return lRecarEfet

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma ³Lj7RCRecCelºAutor  ³ Vendas Cliente     º Data ³  07/07/2012 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Faz o tratamento da "Recarga de Celular".                  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ SIGALOJA - Recarga de Celular                              º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7RCRecCel( nVlrUnit, cCodProd, lTefPendCS, lFirstPrd )

Local lRet		:= .F.
Local cSeqTrans := ""

If Len(aRegTefRC) > 0
	cSeqTrans 	:= aRegTefRC[1][1]
Else
	cSeqTrans := M->LQ_NUM //Tratamento da sequencia do TEF
Endif

lRet := oTef:LjRecCelProd( @nVlrUnit	, Nil		, Nil			, Nil	, ;
							cSeqTrans	, cCodProd	, @lTefPendCS )
If lRet
	lTefPendCS  := .T.
	aAdd(aRegTefRC,{oTef:cCupom,oTef:cData,oTef:cHora,.T.})
Else
	If Len(aRegTefRC) == 0
		lTefPendCS  := .F.
	Endif
	aAdd(aRegTefRC,{oTef:cCupom,oTef:cData,oTef:cHora,.F.})
Endif

Return lRet

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7RCImpRCºAutor  ³ Vendas Cliente     º Data ³  07/07/2012 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Verifica se tem "Recarga de Celular" pendente para         º±±
±±º          ³ impressao de comprovante.                                  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ SIGALOJA - Recarga de Celular                              º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7RCImpRC()
Local lRet := .F.
lRet := Len(aRegTefRC) > 0
Return lRet

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7VlFieldºAutor  ³ Vendas Cliente     º Data ³  07/07/2012 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Funcao executada na validacao de campos (MsGetDados).      º±±
±±º          ³ Propriedade "cFieldOk" da MsGetDados.                      º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ LOJA701                                                    º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7VlField(cTrig)
Local lRet 			:= .T.
Local cField 		:= ""
Local nPosProd	 	:= aPosCpo[Ascan(aPosCpo,{|x| Alltrim(Upper(x[1])) == "LR_PRODUTO"})][2]	// Posicao da codigo do produto
Local cProd      	:= aCols[n][nPosProd]
Local nPosValDesc	:= aPosCpo[Ascan(aPosCpo,{|x| Alltrim(Upper(x[1])) == "LR_VALDESC"})][2]	// Posicao da quantidade
Local nGarant	 	:= 0
Local lGE			:= FindFunction("LjUP104OK") .AND. LjUP104OK() // Validação do Conceito Garantia Estendida
Local cMvLjTGar		:= SuperGetMV("MV_LJTPGAR",,"GE")  // Se trabalha com GE
Local lLog4         := SuperGetMv("MV_LJRECIT", , .F.) .And. Subs(LJGetProfile("LOGERRO"),4,1) == "S"  // Log de Recuperacao, grava as parcelas
Local xBackup
Local nPosField 	:= 0
Local nPosValePre	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_VALEPRE"})	// Posicao do codigo do Vale Presente
Local lLibQtdGE		:= SuperGetMv("MV_LJLIBGE", , .F.) // Libera quantidade da garantia estendida  .. por default é Falso
Local lL2IGarItem	:= SLR->(FieldPos("LR_ITEMGAR")) > 0			// Verifica a existencia do campo L2_VLGAPRO dias de garantia
Local nPGarItem		:= iIf(lL2IGarItem, aScan(aHeader,{|x| Upper(Alltrim(x[2])) == "LR_ITEMGAR"}) ,0)
Local nItem			:= aScan(aHeader,{|x| Upper(Alltrim(x[2])) == "LR_ITEM"})
Local nQtdItem		:= aScan(aHeader,{|x| Upper(Alltrim(x[2])) == "LR_QUANT"})
Local nQtdPai		:= 0
Local lSFinanc      := AliasIndic("MG8") .AND. SuperGetMV("MV_LJCSF",,.F.)	// Valida implementação do servico financeiro
Local cMvLjTSF		:= SuperGetMV("MV_LJTPSF",,"SF")	// tipo servico financeiro
Local nColPosDel 	:= Len(aCols[1]) //Posicao deletado
Local nPosItSer 	:= IIF(lSFinanc, Ascan(aHeader,{|x| Alltrim(Upper(x[2])) == "LR_ITEMCOB"}), 0)
Default cTrig       := "ACS"

cChkProd := cTrig

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Efetua validacoes referente a "Recarga de Celular"³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If Lj7RCAtiva() //Verifica se a configuracao de "Recarga de Celular" estah ativa
	cField := Replace(ReadVar(),"M->", "")

	If cField <> "LR_PRODUTO" .And. Lj7RCPrdRC(GdFieldGet("LR_PRODUTO")) //Verifica se o produto informado eh "Recarga de Celular"
		// Campos que NAO podem ser alterados na Getdados quando o produto for "Recarga de Celular"
		If cField $ "LR_ENTREGA|LR_FDTENTR"
			MsgAlert(STR0290) //"Não é permitido alterar este campo devido ser produto Recarga de Celular."
			lRet := .F.
		EndIf
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Efetua validacoes referente ao "Vale Presente"	 ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If nPosValePre > 0
	cField := Replace(ReadVar(),"M->", "")

	If cField <> "LR_PRODUTO" .And. Len(aColsDet) >= n .And. !Empty(aColsDet[n][nPosValePre]) //Verifica se o produto eh Vale Presente
		// Campos que NAO podem ser alterados na Getdados quando o produto for "Vale Presente"
		If cField $ "LR_ENTREGA|LR_FDTENTR"
			MsgAlert(STR0336) //"Não é permitido alterar este campo devido ser um item de Vale Presente."
			lRet := .F.
		EndIf
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Efetua validacoes referente a "Recarga de Cartao Presente" (Gift Card)³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If FindFunction("Lj7CP_OK") .And. Lj7CP_OK() .And. Lj7CP_Ativ() //Verifica se a configuracao de "Recarga de Cartao Presente" (Gift Card) estah ativa
	cField := Replace(ReadVar(),"M->", "")

	If cField <> "LR_PRODUTO" .And. Lj7CP_Prod(GdFieldGet("LR_PRODUTO")) //Verifica se o produto informado eh "Recarga de Cartao Presente" (Gift Card)
		// Campos que NAO podem ser alterados na Getdados quando o produto for "Recarga de Cartao Presente" (Gift Card)
		If cField $ "LR_ENTREGA|LR_FDTENTR"
			MsgAlert(STR0323) //"Não é permitido alterar este campo devido ser um item de Recarga de Cartão Presente."
			lRet := .F.
		EndIf
	EndIf
EndIf

If lGE .Or. lSFinanc
	If Ascan(aPosCpo,{|x| Alltrim(Upper(x[1])) == "LR_GARANT"}) > 0
		nGarant	:= aPosCpo[Ascan(aPosCpo,{|x| Alltrim(Upper(x[1])) == "LR_GARANT"})][2]
	EndIf

	cField := Replace(ReadVar(),"M->", "")

	If cField <> "LR_PRODUTO"
		If SB1->(DbSeek(xFilial("SB1")+cProd)) .And. SB1->B1_TIPO==cMvLjTGar
			// Campos que NAO podem ser alterados na Getdados quando o produto for Garantia Estendida e parametro MV_LJLIBGE estiver .F."
			If cField $ If(!lLibQtdGE,"LR_QUANT|LR_ENTREGA|LR_FDTENTR","LR_ENTREGA|LR_FDTENTR")
				MsgAlert(STR0298) //"Não é permitido alterar este campo devido ser produto Garantia Estendida."
				lRet := .F.
			ElseIF nPGarItem > 0 .AND. cField $ "LR_QUANT" .AND. lLibQtdGE  // se libera a alteracao quantidade da GE , verifica se esta maior que a qtd do produto
			// busca quantidade digitada no registro vinculado ( produto que possui garantia )
				nQtdPai := aCols[AScan(aCols,{|x|,x[nItem]==aCols[n][nPGarItem]})][nQtdItem]
				If nQtdPai < M->LR_QUANT
					MsgAlert(STR0337) //"Quantidade de Garantia não poder ser maior que a do produto."
					lRet := .F.
				EndIf
			EndIf
		ElseIf nGarant >0 .And. !Empty(aCols[n][nGarant])  // aqui so entra o produto que tem garantia por causa do tipo # GE
			If cField $ "LR_QUANT"  .AND. !lLibQtdGE
				MsgAlert(STR0298) //"Não é permitido alterar este campo devido ser produto Garantia Estendida."
				lRet := .F.
			ElseIF nPGarItem > 0 .AND. cField $ "LR_QUANT" .AND. lLibQtdGE  // se libera a alteracao quantidade da GE , verifica se esta maior que a qtd do produto
			    // busca quantidade digitada no registro vinculado ( produto garantia, tipo GE )
				nQtdFilho := aCols[AScan(aCols,{|x|,x[nItem]==aCols[n][nPGarItem]})][nQtdItem]
				If nQtdFilho > M->LR_QUANT
					MsgAlert(STR0338) //"Quantidade do Produto não poder ser menor que a do produto Garantia."
					lRet := .F.
				EndIf

			EndIf
		ElseIf cField $ "LR_QUANT" .AND. SB1->(DbSeek(xFilial("SB1")+cProd)) .AND. (lSFinanc .AND. SB1->B1_TIPO == cMvLjTSF)
			MsgAlert(STR0343) //"Não é permitido alterar este campo devido ser produto Serviço Financeiro."
			lRet := .F.
		ElseIf cField $ "LR_QUANT|LR_DESC|LR_VALDESC" .AND. lSFinanc .AND. aScan(aCols, {|x|, x[nPosItSer] == aCols[n][nItem] .And. !x[nColPosDel]}) > 0
			MsgAlert(STR0368) //#"Não é permitido alterar este campo pois existem Serviços Financeiros vinculados a este produto."
			lRet := .F.
		EndIf
	EndIf

EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Efetua validacoes referente a "Kit de Produtos"  ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If Lj7IsKit(aCols[n][nItem], aCols[n][nPosProd]) .And. Len(aProdKit) > 0 .AND. !(IsInCallStack("Lj7LancItem"))
	cField := Replace(ReadVar(),"M->", "")
	If cField <> "LR_PRODUTO" .AND. cField <> "LR_DESC"
		// Campos que podem ser alterados
		
		If cChkProd <> "GET" .And. !(cField $ "LR_ENTREGA|LR_FDTENTR")
			Alert(STR0413) // "Não é possível alterar este produto pois pertence a um Kit de Produtos."
			lRet := .F.
		EndIf
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Cria/Altera Log de Recuperacao   ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If	lLog4 .And. lRet .And. ( "LR_PRODUTO" $ AllTrim(ReadVar()) .Or. !Empty(cProd) ) ;
	.And. !IsInCallStack("lj7VlItem") .And. Len(aColsDet) > 0

	cField    := AllTrim(Replace(ReadVar(),"M->", ""))
	nPosField := aScan( aHeader, {|x| AllTrim(x[2])==cField})

	//Faz backup do valor do aCols para uso posterior
	xBackup := aCols[n][nPosField]

	//Atribui o valor digitado para gravação correta do Log de Recuperacao
	aCols[n][nPosField] := &(AllTrim(ReadVar()))

	LJAltLogR(M->LQ_NUM, aCols, n)

	aCols[n][nPosField] := xBackup

EndIf

Return lRet

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºFuncao    ³LjKeyFuncsºAutor  ³ Vendas Cliente     º Data ³ 05/Mar/2013 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Verifica se permite executar as funcoes definidas nas      º±±
±±º          ³ teclas de atalho (F4, F5, F6).                             º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ ExpL1 - True para Permitir                                 º±±
±±º          ³         False para Nao Permitir                            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ Logico -  .T.(Permite) ;   .F.(Nao Permite)                º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ LOJA701                                                    º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function LjKeyFuncs(nTecla)

Local lRet 	:= .T.

If nTecla == 1
	cTecla:= "F4"
ElseIf nTecla == 2
	cTecla:= "F5"
ElseIf nTecla == 3
	cTecla:= "F6"
EndIf

//Se NAO for Visualizacao e alguma consulta padrao F3 estiver aberta, nao permite a acao das teclas de atalho
If Type("InConPad") <> "U" .And. InConPad .AND. Iif( ValType(oGetVA:nOpc)=="N" .AND. oGetVA:nOpc <> 2, .T., .F. )
	lRet := .F.
EndIf


//Verifica se o usuario esta definindo/alterando a forma de pagamento. Neste caso a tela de edicao da forma de pagamento
//esta aberta, entao nao permite a acao das teclas de atalho enquanto a telinha nao for fechada pelo usuario
If lRet .And. IsInCallStack("Lj7CondPg") .Or. IsInCallStack("Lj7AltPgt") .Or. IsInCallStack("Lj7AltPgSi")
	lRet := .F.
EndIf

//Verifica se sistema esta processando a gravacao, entao nao permite a acao das teclas de atalho enquanto nao for concluido o processamento da funcao "Lj7Gravacao"
If lRet .And. IsInCallStack("Lj7Gravacao")
	lRet := .F.
EndIf

//Verifica se sistema esta exectando a funcao Lj7Sair, entao nao permite a acao das teclas de atalho enquanto nao for concluido o processamento dessa funcao.
If lRet .And. IsInCallStack("Lj7Sair")
	lRet := .F.
EndIf

LjGrvLog("","Pressionou a tecla de atalho ("+cTecla+")",lRet)

//Ponto de Entrada que permite validar se prossegue com a execucao da acao da tecla de atalho pressionada (F4, F5, F6).
If lRet .And. ExistBlock("LJ701Key")
	lRet := ExecBlock( "LJ701Key", .F., .F. )
	LjGrvLog("","Pressionou a tecla de atalho ("+cTecla+") - Retorno do PE LJ701Key",lRet)
EndIf

Return lRet

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7ImpDanfeºAutor  ³ Vendas Cliente    º Data ³  22/03/2013 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Imprime Danfe da NFC-e								      º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ LOJA701                                                    º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7ImpDanfe()
Local cMsg		:= ""
Local lImprime 	:= .T.

If FindFunction("LjNfceImp") .And. SL1->(FieldPos("L1_KEYNFCE")) > 0
	If SL1->L1_SITUA == "X2"
		lImprime := .F.
		cMsg 	 := STR0389 //"Impressão não permitida. A NFC-e desta venda está cancelada."
	ElseIf SL1->L1_SITUA $ "X0|X1|X3" .Or. SL1->L1_STORC == "A"
		lImprime := .F.
		cMsg 	 := STR0390 //"Impressão não permitida. A NFC-e desta venda foi enviada para cancelamento."
	ElseIf !Empty(SL1->L1_KEYNFCE) .AND. AllTrim(SL1->L1_KEYNFCE) <> '0' .And. SL1->L1_TPORC == 'E'
		lImprime := .T.
	Else
		lImprime := .F.
		cMsg 	 := STR0304	//"Impressão não permitida. Não foi emitido NFC-e para esse registro!"
	EndIf
EndIf

If lImprime
	LjMsgRun( STR0301+SL1->L1_NUM+STR0302+SL1->L1_DOC,, {|| LjNfceImp(SL1->L1_FILIAL,SL1->L1_NUM) } ) //"Aguarde... Imprimindo NFC-e Orcamento: "   //" - Doc.: "
ElseIf !Empty(cMsg)
	MsgStop(cMsg)
EndIf

Return

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³Lj7140Exc		 ³ Vendas Cliente    º Data ³  22/03/2013 	  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Cancela Documento									      º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ LOJA701                                                    º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7140Exc()
Local lEmitNfce		:= LjEmitNFCe()	// Sinaliza se utiliza NFC-e

If lEmitNfce .AND. SL1->L1_SITUA $ "X0|X1|X2"
	Alert(STR0447)	//"NFC-e em processo de cancelamento, por gentileza aguarde!""
Else	
	LJ140Exc( "SL1", SL1->(Recno()), 2 )
EndIf 

Return Nil

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³LjNFePar   		 ³ Vendas Cliente    º Data ³  03/07/2013 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Rotina(TSS) de Parametros da NFC-e						  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ LOJA701                                                    º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function LjNFCePar()
Local cURL := PadR(GetNewPar("MV_NFCEURL","http://"),250)
Local cMvVerNFCe 	:= "" 
Local aGetMvTSS 	:= {}

// Verifica se as informações de URL do TSS estão corretas (teste de conexão)
If CTIsReady(cURL,3,.T.)
	SpedNFePar("65")
EndIf

//Obtemos a versao da NFC-e do TSS
aGetMvTSS := LjGetMVTSS("MV_VERNFCE")

If Len(aGetMvTSS) >= 2 .And. aGetMvTSS[1] 
	cMvVerNFCe := AllTrim( aGetMvTSS[2] )
		
	//Atualiza parâmetro MV_VERNFCE para manter legado, apesar de considerar sempre a versão do TSS		
	If AllTrim(cMvVerNFCe) <> AllTrim(SuperGetMv("MV_VERNFCE",, "")) 
		PutMv("MV_VERNFCE" , cMvVerNFCe)
	EndIf
EndIf

Return Nil

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³SpedNfeCfg   		 ³ Vendas Cliente    º Data ³  03/07/2013 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Rotina(TSS) de Configuracoes da NFC-e					  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ LOJA701                                                    º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function LjNFCeCfg()
	SpedNfeCfg("65")	//65-NFC-e conforme definido no SPEDNFE
Return Nil

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³LjNFCeMnt   		 ³ Vendas Cliente    º Data ³  03/07/2013 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Rotina(TSS) de MOnitor da NFC-e							  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ LOJA701                                                    º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function LjNFCeMnt()
	SpedNfe1Mnt("65")	//65-NFC-e conforme definido no SPEDNFE
Return Nil

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³Lj7CancContg   ³ Autor ³ Vendas CRM		   ³ Data ³ 17/12/12 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Faz o Cancelamento das contingencias da tabela MES	         ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ Lj7CancContg(aMesRec)												  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ ExpN1:= aMesRec - Array com os recnos da Mes a cancelar    ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Retorno	 ³ Nil                                                       ³±±
±±³          ³                                     						     ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 	³ LOJA701 													            ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7CancContg(aMesRec)

Local nX 				:= 0				// Variavel de controle
Local lMesIsLocal 	:= .F.				// Indica se a contingencia esta local
Local aArea 			:= GetArea()		// Guarda area

Default aMesRec := {}  				// Array com os recnos da MES a serem cancelados

If Len(aMesRec) > 0

	DbSelectArea("MES")

	For nX := 1 To Len(aMesRec)

		MES->(DbGoto (aMesRec[nX]))
		If !Eof() .AND. MES->MES_SITUA <> "TX"
			RecLock( "MES",.F.)
			DbDelete()
			MsUnlock()
		EndIf
	Next nX

EndIf

RestArea( aArea )

Return lMesIsLocal

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³LjNFCeExp   		 ³ Vendas Cliente    º Data ³  16/08/2013 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Rotina(TSS) para Exportar XML da NFC-e					  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ LOJA701                                                    º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function LjNFCeExp()
	SpedExport(3)  		//3-NFC-e conforme definido no SPEDNFE
Return Nil


/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³LjNFCeExp   		 ³ Vendas Cliente    º Data ³  16/08/2013 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Rotina(TSS) para Exportar XML da NFC-e					  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ LOJA701                                                    º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function LjNFCeEven()
	SpedCCePar(/*nEvento*/,.F.,"65")
Return Nil


/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³Lj7VLDVen   ³ Autor ³ Vendas Cliente       ³ Data ³ 24/10/13 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Validação de vendedor no item	para que não seja parceiro	³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ ExpL1:= Lj7VLDVEN()                                         ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ ExpL1 = cCodVend(Codigo do vendedor)						  ³±±
±±³          ³ 															  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Retorno	 ³ ExpL1 = .F.             									  ³±±
±±³          ³                                     						  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701 													  ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7VldVen(cCodVend)

Local lRet			:= .F.						// Retorno Função
Local aAreaSA3 := SA3->(GetArea("SA3")) 	// Armazena area SA3

If !Empty(cCodVend)
	DbSelectarea("SA3")
	DbSetOrder(1) // A3_FILIAL + A3_COD
	If DbSeek(xFilial("SA3") + AllTrim(cCodVend))
		If SA3->A3_TIPO == "P"
			lRet := .F.
		Else
			lRet := .T.
		EndIf
	Else
		lRet := .F.
	EndIf
Else
	lRet := .T.
EndIf

RestArea(aAreaSA3)

Return(lRet)


/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³Lj7VLDVen   ³ Autor ³ Vendas Cliente       ³ Data ³ 24/10/13 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Validação de vendedor no item	para que não seja parceiro	³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ ExpL1:= Lj7VLDVEN()                                         ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ ExpL1 = cCodVend(Codigo do vendedor)						  ³±±
±±³          ³ 															  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Retorno	 ³ ExpL1 = .F.             									  ³±±
±±³          ³                                     						  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701 													  ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7VldPar(cCodVend)

Local lRet			:= .F.						// Retorno Função
Local aAreaSA3 	:= SA3->(GetArea("SA3"))	// Armazena area SA3

Default cCodVend := ""	// Codigo do Vendedor

If !Empty(cCodVend)
	DbSelectarea("SA3")
	DbSetOrder(1) // A3_FILIAL + A3_COD
	If DbSeek(xFilial("SA3") + AllTrim(cCodVend))
		If SA3->A3_TIPO == "P"
			lRet := .T.
		Else
			lRet := .F.
		EndIf
	Else
		lRet := .F.
	EndIf
Else
	lRet := .T.
EndIf

RestArea(aAreaSA3)

Return(lRet)

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³Lj7LancItem³ Autor ³ Vendas Cliente       ³ Data ³ 24/10/13 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Pesquisa item para lancar fora da getdados				  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Retorno	 ³ lRet = .T.												  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701													  ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7LancItem(cProduto,nQuant,lVldInc, nPrcVen)

Local lRet			:= .F. 											// Variavel de retorno
Local nIndex  		:= SB1->(IndexOrd())							// Numero do indice
Local nPosQuant		:= 0											// Posicao Quantidade
Local lTrcMoeda		:= SuperGetMV("MV_TRCMOED",,.T.)				// Indica se permite escolha de moeda
Local nAuxMoedaPrv	:= 0   											// Auxiliar Moeda
Local lCenVenda 	:= SuperGetMv("MV_LJCNVDA",,.F.)				// Parâmetro se utiliza cenário de venda
Local cTabPrecos	:= ""											// Tabela de Preços
Local cDA0While		:= ""											// Variável While do DA0
Local nValorDe		:= 0											// Valor 279do preço DA1
Local nTamProduto	:= TamSX3("L2_PRODUTO")[1]						// Tamanho no M->LQ_PRODUTO
Local nTamCodSLK	:= TamSX3("LK_CODBAR")[1]						// Tamanho no LK_CODBAR
Local lContinua 	:= .T.
Local lLJ70101 		:= ExistBlock( "LJ70101" )

Default nQuant		:= 1											// Quantidade
Default cProduto	:= M->LQ_PRODUTO
Default lVldInc		:= .F.											// Valida inclusao do produto
Default nPrcVen 	:= 0

//Ponto de Entrada para validar de continua ou nao registrar do item da venda, quando o produto eh incluindo atraves do campo superior da tela (LQ_PRODUTO)
If lLJ70101
	lContinua := ExecBlock( "LJ70101", .F., .F., {"1"} ) //O tipo "1" indica que o P.E. esta sendo chamado antes de incluir o item na venda.
EndIf

If lContinua
	If nQuant < 0.001
		nQuant := 1
	EndIf
	
	If Empty(cProduto)
		If IsInCallStack("LJRFPESQPROD")
			lRet := .F.
		Else		// Se vazio, sai do campo
			If ProcName(3) <> "LJ7VENDA"
                lRet := .T.                        
            ElseIf lSaidaVld
                lRet := .T.
            EndIf
		EndIf
		
		lSaidaVld := .T. //Altera flag para saida do valid
	Else
	
		nPosQuant	:= AT("*",cProduto)
		If nPosQuant > 0 .AND. FindFunction("STIComma")
			nQuant := STIComma(SubStr(cProduto,1,nPosQuant-1))
			cProduto	:= SubStr(cProduto,nPosQuant+1)
			lSaidaVld   := .F. //Altera flag para saida do valid
		EndIf
	
		//Pesquisa Produto
		SB1->(DbsetOrder(1))
		If !SB1->(Dbseek(xFilial("SB1")+cProduto,.F.))
			SB1->(DbsetOrder(5))
			If !SB1->(Dbseek(xFilial("SB1")+cProduto,.F.))
				SLK->(DbSetOrder(1))
				cProduto := PADR(Alltrim(cProduto),nTamCodSLK) 
				If !SLK->(DbSeek(XFilial("SLK")+cProduto,.F.))
					//Apenas irá pegar um codigo similar caso tenha mais de 12 casas (no caso de ter data de validade no codigo de barras)
					If !SLK->(DbSeek(XFilial("SLK")+Substr(cProduto,1,12),.F.))
						MsgStop("Código de Produto não localizado!" + CHR(10) + " - " + STR0424)
						M->LQ_PRODUTO := Space(nTamProduto)
						Return(.F.)
						lAchou := .F.
					Else
						SB1->(DbSetOrder(1))
						If !SB1->(Dbseek(xFilial("SB1")+SLK->LK_CODIGO,.F.))
							MsgStop("Erro de acesso ao produto SLK: "+SLK->LK_CODIGO)
							M->LQ_PRODUTO := Space(nTamProduto)
							Return(.F.)
							lAchou := .F.
						Else
							cProduto := SLK->LK_CODIGO
						EndIf
					EndIf	
				Else
					SB1->(DbSetOrder(1))
					If !SB1->(Dbseek(xFilial("SB1")+SLK->LK_CODIGO,.F.))
						MsgStop("Erro de acesso ao produto SLK: "+SLK->LK_CODIGO)
						M->LQ_PRODUTO := Space(nTamProduto)
						Return(.F.)
						lAchou := .F.
					Else
						cProduto 	:= SLK->LK_CODIGO
											
						If SLK->LK_QUANT <> 0
							nQuant	:= nQuant * SLK->LK_QUANT
						Else
							LjGrvLog("Registro_Item","Quantidade foi ajustada para 1. Item nao possui quantidade cadastrada na SLK(LK_QUANT=0). LK_CODIGO:"+SLK->LK_CODIGO)					
						EndIf
					EndIf
				EndIf
			Else
				cProduto := SB1->B1_COD
			EndIf
	   Else
			cProduto := SB1->B1_COD
	   EndIf
	
		// Verificar se o preço foi digitado
		If !lCenVenda .AND. SB1->B1_TIPO <> "KT"
			// Pesquisa SB0
			DbSelectArea('SB0')
			DbSetOrder(1)
			If DbSeek(xFilial('SB0')+SB1->B1_COD)
				If lTrcMoeda
					nAuxMoedaPrv := Max(&("SB0->B0_MOEDA" + Lj7DefTab()),1)
				Else
					nAuxMoedaPrv := 1
				EndIf
				nAuxVUnit	:= Round(xMoeda(&("SB0->B0_PRV" + Lj7DefTab()),nAuxMoedaPrv,nMoedaCor,dDataBase,nDecimais+1,,nTxMoeda),nDecimais)
				If Empty(nAuxVUnit)
					MsgStop("Favor cadastrar o preço! Produto "+SB1->B1_COD)
					M->LQ_PRODUTO := Space(nTamProduto)
					lAchou := .F.
					Return(.F.)
				EndIf
			Else
				MsgStop("Erro de acesso ao produto SB0: "+SB1->B1_COD)
				M->LQ_PRODUTO := Space(nTamProduto)
				lAchou := .F.
				Return(.F.)
			EndIf
		ElseIf SB1->B1_TIPO <> "KT"
			cTabPrecos  := LjXETabPre(M->LQ_CLIENTE,M->LQ_LOJA)
			DbSelectArea("DA0")
			DbSetOrder(1) //DA0_FILIAL+DA0_CODTAB
			If DbSeek(xFilial("DA0")+cTabPrecos)
				cDA0While := xFilial("DA0")
				While DA0->( ! Eof()) .and. cDA0While == DA0->DA0_FILIAL .AND. DA0->DA0_CODTAB = cTabPrecos
					If Date() >= DA0->DA0_DATDE .AND. (Date() <= DA0->DA0_DATATE .OR. EMPTY(DA0->DA0_DATATE))
						DbSelectArea("DA1")
						DbSetOrder(1) //DA1_FILIAL+DA1_CODTAB+DA1_CODPRO+DA1_INDLOT+DA1_ITEM
						If DbSeek(DA0->DA0_FILIAL+DA0->DA0_CODTAB+cProduto)
							nValorDe := DA1->DA1_PRCVEN
							Exit
						Else
							MsgStop("Preço não encontrado na tabela DA1: Produto "+SB1->B1_COD)
							M->LQ_PRODUTO := Space(nTamProduto)
							lAchou := .F.
							Return(.F.)
						EndIf
					EndIf
					DA0->(dbskip())
				End
			Else
				MsgStop("Erro de acesso à tabela de preços DA0: "+SB1->B1_COD)
				M->LQ_PRODUTO := Space(nTamProduto)
				lAchou := .F.
				Return(.F.)
			EndIf
			If nValorDe <= 0
				MsgStop("Favor cadastrar o preço na tabela "+Alltrim(cTabPrecos)+"! Produto "+SB1->B1_COD)
				M->LQ_PRODUTO := Space(nTamProduto)
				lAchou := .F.
				Return(.F.)
			EndIf
		EndIf
	
		M->LQ_PRODUTO := Space(nTamProduto)
		Lj7SetKEYs(.F.)
	
		If IsInCallStack("LJRFPESQPROD") .Or. lVldInc
			lRet := Lj7ProdInc(cProduto,nQuant, nPrcVen)
		Else			// Loop em LQ_PRODUTO
			Lj7ProdInc(cProduto,nQuant, nPrcVen)
		EndIf
		
		//Ponto de Entrada para permitir realizar acoes apos registrar o item da venda atraves do campo superior da tela (LQ_PRODUTO).
		//Neste caso nao ira impedir a inclusao do produto, pois o mesmo ja foi incluido, apenas permite fazer acoes complementares apos incluir o produto.
		If lLJ70101
			ExecBlock( "LJ70101", .F., .F., {"2"} ) //O tipo "2" indica que o P.E. esta sendo chamado apos incluir o item na venda.
		EndIf
	
		Lj7SetKEYs(.T.)
	EndIf
	
EndIf

SB1->(Dbsetorder(nIndex))

Return(lRet)

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³Lj7ProdInc³ Autor ³ Vendas Cliente        ³ Data ³ 24/10/13 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ lancar o item fora da getdados 								³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³                                                            ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Retorno	 ³ lRet = .T.             									  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701 													  ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function Lj7ProdInc(cProduto,nQuant, nPrcVen)

Local nRegSX3 		:= SX3->(Recno()) //Recno do indice
Local nOrdSX3 		:= SX3->(IndexOrd()) //Ordem do indice
Local nPosPrd 		:= aScan( aHeader, {|x| Alltrim(Upper(x[2])) == "LR_PRODUTO"  } ) //Posicao do campo LR_PRODUTO
Local nPosQua 		:= aScan( aHeader, {|x| Alltrim(Upper(x[2])) == "LR_QUANT"    } ) //Posicao do campo LR_QUANT
Local nPosUni 		:= aScan( aHeader, {|x| Alltrim(Upper(x[2])) == "LR_VRUNIT"   } ) //Posicao do campo LR_VRUNIT
Local nPosItem 		:= aScan( aHeader, {|x| Alltrim(Upper(x[2])) == "LR_ITEM"  	} ) //Posicao do campo LR_ITEM
Local nPosDescto	:= aScan( aHeader, {|x| Alltrim(Upper(x[2])) == "LR_VALDESC"  	} ) //Posicao do campo LR_ITEM
Local nX 			:= 0 //Variavel de loop
Local nyQ			:= 0 //Variavel de loop
Local nLocalEst 	:= "" //Local de estoque
Local lRet			:= .T.
Local lAddNaCols	:= .F.	//sinaliza se adicionou N
Local nQtdPrd   	:= 0
Local nLinPrd   	:= 0
Local lmvLjProdR	:= SuperGetMV("MV_LJPRODR",,.F.) //Modo de como será registrado o item atraves do LQ_PRODUTO
Local nPosReser		:= Ascan(aPosCpoDet, {|x| Alltrim(Upper(x[1])) == "LR_RESERVA"})	// Posicao do Codigo da Reserva
Local lNovaLinha 	:= .T. //Indica se inclui uma nova linha para adicionar o produto ou se atualiza a linha ja existente
Local cBkpReadVar	:= "" //Backup da Variável
Local nValePre		:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_VALEPRE"}) //Posicao do vampo de vale presente
Default  nPrcVen := 0
Default  nQuant  := 0

If Empty(cProduto)
	If IsInCallStack("LJRFPESQPROD")
		Return(.F.)
	Else
		Return(.T.)
	EndIf
EndIf

SB1->(dbSetOrder(1))
If SB1->(dbSeek(xFilial("SB1")+cProduto))
	cProduto := SB1->B1_COD
	nLocalEst := SB1->B1_LOCPAD
Else
	MsgStop(STR0383,STR0385) //"Código de Produto não localizado!" # "Saldo em Estoque"
	Return(.F.)
EndIf

If N == 1
	Eval(oGetVa:oBrowse:bGotFocus)
EndIf

lAddNAcols := !Empty(aCols[N,nPosPrd])

If lAddNAcols
	
	If lmvLjProdR .And. nPosReser > 0 .And. Empty(aColsDet[N][nPosReser])
	
		For nyQ := 1 to Len(aCols)
			If !aTail( aCols[nyQ] ) .AND. aCols[nyQ][nPosPrd] == cProduto .And. Empty(aColsDet[nyQ][nPosReser])
				nLinPrd := nYQ
				Exit
			EndIf
		Next
		
		If nLinPrd > 0
			N := nLinPrd
			nQtdPrd 	:= aCols[N,nPosQua]
			lNovaLinha 	:= .F.
		Else
			lNovaLinha 	:= .T.
		EndIf
		
	Else
		
		lNovaLinha := .T.
		
	EndIf
	
	If lNovaLinha //Adiciona uma nova linha na GetDados
		N := Len(aCols)+1
		Aadd(aCols,Array(Len(aHeader)+1))
		
		For nyQ := 1 To Len(aHeader)  
	    	If !(aHeader[nyQ,2] $ "L2_ALI_WT|L2_REC_WT")
				aCols[N,nyQ] := CriaVar(aHeader[nyQ,2])     
			EndIf
		Next
		
		aCols[N,nPosItem] 	:= StrZero( Len(aCols), Len(aCols[N,nPosItem]) )
		aCols[N,nPosPrd]  	:= cProduto
	EndIf
	
	oGetVa:oBrowse:nAt	:= N
	
	If lmvLjProdR
		aCols[N,nPosQua]  := nQuant + nQtdPrd
	Else
		aCols[N,nPosQua]  := nQuant
	EndIf	
	
	aCols[N,Len(aHeader)+1]   := .F.	
	
Else
	aCols[N,nPosPrd]    := cProduto
	aCols[N,nPosQua]    := nQuant
EndIf  
    
/*********** Produto ***********/
cBkpReadVar	:= ReadVar() //Backup da Variável
__ReadVar	:= "M->LR_PRODUTO"
M->LR_PRODUTO := aCols[N,nPosPrd]
lRet := Lj7Prod(.T.) .AND. LjInfoKit()
__ReadVar := cBkpReadVar


If lRet 
	cBkpReadVar	:= ReadVar()

	SX3->(dbSetOrder(2))
	SX3->(dbSeek("LR_PRODUTO"))
	If ExistTrigger("LR_PRODUTO") .and. N != Nil
		RunTrigger(2,n)
	EndIf
	
	/*********** Quant ***********/
	M->LR_QUANT          := aCols[N,nPosQua]
	__ReadVar            := "M->LR_QUANT"
	If nValePre == 0 .OR. Empty(aColsDet[n][nValePre])
		Lj7VlItem(1)
	EndIf
	SX3->(dbSetOrder(2))
	SX3->(dbSeek("LR_QUANT"))
	If ExistTrigger("LR_QUANT")
		M->LR_QUANT  := aCols[N,nPosQua]
		RunTrigger(2,n)
	EndIf
	/*********** Vlr Item ***********/
	SX3->(dbSetOrder(2))
	SX3->(dbSeek("LR_VRUNIT"))
	If ExistTrigger("LR_VRUNIT") .and. N != Nil
		M->LR_VRUNIT := aCols[N,nPosUni]
		RunTrigger(2,n)
	EndIf
	
	If N != Nil .AND. nPrcVen > 0 .AND.  nPrcVen < aCols[N,nPosUni]
		__ReadVar            := "M->LR_VALDESC"
		nQuant     := IIf(nQuant > 0 , nQuant , 1)		
		M->LR_VALDESC := (aCols[N,nPosUni] * nQuant )  - (nPrcVen * nQuant )
		aCols[N,nPosDescto] := M->LR_VALDESC
		Lj7VlItem(4)
		If ExistTrigger("LR_VALDESC") //.and. N != Nil
			M->LR_VALDESC := aCols[N,nPosDescto]
			RunTrigger(2,n)
		EndIf
	EndIf
	
	
	SX3->(dbSetOrder(nOrdSX3))
	SX3->(dbGoto(nRegSX3))
	__ReadVar := cBkpReadVar
	
	oGetVa:oBrowse:nColPos := aScan(aHeader,{ |X| Upper(AllTrim(x[2])) == "LR_PRODUTO"     })
	oGetva:oBrowse:nRowPos := Len(aCols)
	oGetva:oBrowse:nLen    := Len(aCols)
	oGetVa:lNewLine := .F.
	If IsInCallStack("LJRFPESQPROD")
		oGetva:oBrowse:SetFocus()
	EndIf
	oGetva:oBrowse:Refresh()
Else
	//tratamento para excluir aCols adicionado sem registro de item
	If lAddNAcols 		
		aDel(aCols,N)
		N -= 1				//restaura contador de item
		aSize(aCols,N)	//ajusta tamanho do aCols para valor antes do registro (aColsDet nao precisa ser ajustado, nao eh adicionado quando ocorre erro)
	Else
		aCols[N,nPosPrd]    := ""
		aCols[N,nPosQua]    := 0
	EndIf	
EndIf

Return .T.

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³Lj7RatDesc ³ Autor ³ Vendas Cliente       ³ Data ³ 03/07/14 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Rotina para ratear o valor total de desconto pelos itens	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³                                                            ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Retorno	 ³ 			             									  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701 													  ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7RatDesc(aSL1, aSL2)

Local aArea			:= GetArea()			// Armazena ultima area utilizada
Local nFor			:= 0					// Contador do For
Local nVlrItem		:= 0					// Valor do item
Local nVlProp		:= 0					// Valor proporcional
Local nVlrDescIT	:= 0					// Valor de desconto do item
Local nPrcDesc		:= 0					// Percentual de desconto no total da venda
Local nDescNF  		:= 0					// Valor do desconto no total da venda
Local nPos			:= 0					// Posicao do campo no array
Local nRateio		:= 0					// Valor total do rateio
Local nDifRat		:= 0					// Diferenca entre o rateio e o desconto da venda
Local nPercItm		:= 0					// Percentual de desconto do item
Local nQuant		:= 0					// Quantidade do item

Default aSL1		:= {}					// Array com o cabecalho da venda
Default aSL2		:= {}					// Array com os itens da venda

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Busca o percentual de desconto no total ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
nPos	:= aScan(aSL1, { |x| AllTrim(x[01]) == "L1_DESCNF" })
nPrcDesc := aSL1[nPos][2]

If nPrcDesc > 0

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Rateia desconto pelos itens  ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	For nFor := 1 to Len(aSL2)

		//Quantidade
		nPos	:= aScan(aSL2[nFor], { |x| AllTrim(x[1]) == "L2_QUANT" })
		nQuant := aSL2[nFor][nPos][2]

		//Valor do Item
		nPos	:= aScan(aSL2[nFor], { |x| AllTrim(x[1]) == "L2_VLRITEM" })
		nVlrItem := aSL2[nFor][nPos][2]

		//Valor desconto Item
		nPos	:= aScan(aSL2[nFor], { |x| AllTrim(x[1]) == "L2_VALDESC"})
		nVlrDescIT	:= aSL2[nFor][nPos][2]

		// Verifica o valor proporcional
		nVlProp 	:= A410Arred(((nVlrItem - nVlrDescIT)*(nPrcDesc/ 100)),"D2_TOTAL")

		If nVlProp > 0
		 	nVlrDescIT += nVlProp
		 	nRateio += nVlProp

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Caso seja o ultimo item do Orc Importado verifica se nao houve resido(sobra) no rateio³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If nFor == Len(aSL2)

				nPos	:= aScan(aSL1, { |x| AllTrim(x[01]) == "L1_DESCONT" })
				nDescNF	:= aSL1[nPos][2]

				nDifRat := nDescNF - nRateio

				If Abs(nDifRat) > 0
				 	nVlrDescIT += nDifRat
				 	nRateio += nDifRat
				EndIf

			EndIf

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Atribui os novos valores para o item ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			nPos	:= aScan(aSL2[nFor], { |x| AllTrim(x[1]) == "L2_VALDESC"})
			aSL2[nFor][nPos][2] := nVlrDescIT

			nPos	:= aScan(aSL2[nFor], { |x| AllTrim(x[1]) == "L2_DESC"})
			nPercItm := (nVlrDescIT/nVlrItem)
			aSL2[nFor][nPos][2] := nPercItm * 100

			nVlrItem -= nVlrDescIT
			nPos	:= aScan(aSL2[nFor], { |x| AllTrim(x[1]) == "L2_VLRITEM"})
			aSL2[nFor][nPos][2] := nVlrItem

			nPos	:= aScan(aSL2[nFor], { |x| AllTrim(x[1]) == "L2_VRUNIT"})
			aSL2[nFor][nPos][2] := nVlrItem / nQuant

		EndIf

	Next nFor

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Zera o desconto no total  ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	nPos	:= aScan(aSL1, { |x| AllTrim(x[01]) == "L1_DESCNF" })
	aSL1[nPos][2] := 0

	nPos	:= aScan(aSL1, { |x| AllTrim(x[01]) == "L1_DESCONT" })
	aSL1[nPos][2] := 0

EndIf

RestArea(aArea)

Return

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7GetServ ºAutor  ³ Vendas Clientes         º Data ³ 10/07/14 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDescricao ³ Retorna o valor da variavel logica (static) lVincServ		 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ 													             º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7GetServ()
Return lVincServ

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7SetServ ºAutor  ³ Vendas Clientes         º Data ³ 10/07/14 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDescricao ³ Altera o valor da variavel logica (static) lVincServ			 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ 													             º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7SetServ(lValor)

lVincServ := lValor

Return lVincServ

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj701DelCPºAutor  ³ Vendas Cliente     º Data ³ 26/Jun/2013 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Verifica se na venda tem mais de um item de Recarga de     º±±
±±º          ³ Cartao Presente (Gift Card).                               º±±
±±º          ³ Caso exista mais de um item de Recarga de Cartao Presente, º±±
±±º          ³ nao permite deletar o item de Recarga de Cartao Presente.  º±±
±±º          ³ Desta forma soh resta ao usuario abandonar a venda para    º±±
±±º          ³ cancelar toda a venda.                                     º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ LOJA701                                                    º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function Lj701DelCP( aCols, nItemPos, nPosColPrd )
Local lRet 			:= .T.
Local nInd 			:= 0
Local nColPosDel 	:= Len(aCols[1])

//Percorre todos os itens da venda para verifica se tem mais de um item de Recarga de Cartao Presente (Gift Card).
For nInd:=1 To Len(aCols)

	If !aCols[nInd][nColPosDel] //Somente considera itens nao deletados

		If nInd == nItemPos
			Loop
		EndIf

		//Verifica se o produto informado eh "Cartao Presente" Gift Card)
		If Lj7CP_Prod(aCols[nInd][nPosColPrd])
			lRet := .F.
			Exit
		EndIf

	EndIf

Next nInd

Return lRet



/*/
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    |ObtCpoRG3668	³ Autor ³ Vendas Cliente³ Data ³07/05/15  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ alida si las fechas de vigencia son validas*               ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Retorno   ³ aRotina   retorna o conteudo da variavel A1_ADIC5          ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso       ³ SIGALOJA                                                   ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
/*/

/* Valida si las fechas de vigencia son validas*/
Function ObtCpoRG3668()
Local cA1_ADIC5 := ""
Local cSerie    := Lj7SerArg()

	cA1_ADIC5		:= Posicione( "SA1",1,xFilial("SA1")+M->LQ_CLIENTE+M->LQ_LOJA,"SA1->A1_ADIC5")
	M->LQ_ADIC61  := Posicione( "SA1",1,xFilial("SA1")+M->LQ_CLIENTE+M->LQ_LOJA,"SA1->A1_ADIC61")
	M->LQ_ADIC62  := Posicione( "SA1",1,xFilial("SA1")+M->LQ_CLIENTE+M->LQ_LOJA,"SA1->A1_ADIC62")
	M->LQ_ADIC7   := Posicione( "SA1",1,xFilial("SA1")+M->LQ_CLIENTE+M->LQ_LOJA,"SA1->A1_ADIC7")

	If !Empty(SA1->A1_DESDE) .And. !Empty(SA1->A1_HASTA) .And. cSerie $ ("A")
		If M->LQ_EMISSAO < SA1->A1_DESDE .Or. M->LQ_EMISSAO > SA1->A1_HASTA
			Aviso( OemToAnsi(STR0004), OemToAnsi(STR0365), {STR0028} )
		EndIf
	ElseIf cSerie $ ("A")
		Aviso( OemToAnsi(STR0004), OemToAnsi(STR0366), {STR0028} )
	EndIf

Return cA1_ADIC5




/*/
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    |LjValRG3668	³ Autor ³ Vendas Cliente³ Data ³07/05/15  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Valida si las fechas son validas             ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Retorno   ³ retorna COnteudo logico conforme os campos Q_ADIC5/61/62 e 7³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso       ³ SIGALOJA                                                   ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
/*/


/*Valida si las fechas son validas*/
Static Function LjValRG3668()
Local lRet := .T.
Local lValida := .F.
Local nI		:= 0
Local cMv3668	:= SuperGetMV("MV_CFO3668",.T.,"")
Local cSerie   := Lj7SerArg()
Local nPosLR_CF := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_CF"})

	If !Empty(cMv3668) .And. cSerie $ ("A")
		For nI := 1 To Len(aColsDet)
			If Alltrim(aColsDet[nI][nPosLR_CF]) $ cMv3668 .AND. !MaFisRet(nI,"IT_DELETED") //MaFisRet(nI,"IT_CF")
				lValida := .T.
				exit
			Endif
		Next
	EndIf

	If lValida
		If !((Empty(M->LQ_ADIC5) .And. Empty(M->LQ_ADIC61) .And. Empty(M->LQ_ADIC62) .And. Empty(M->LQ_ADIC7)) .Or.;
			(!Empty(M->LQ_ADIC5) .And. !Empty(M->LQ_ADIC61) .And. !Empty(M->LQ_ADIC62) .And. !Empty(M->LQ_ADIC7)))
				Aviso( OemToAnsi(STR0004), OemToAnsi(STR0367), {STR0028} )
				lRet := .F.
		ElseIf !Empty(SA1->A1_DESDE) .And. !Empty(SA1->A1_HASTA)
			If M->LQ_EMISSAO < SA1->A1_DESDE .Or. M->LQ_EMISSAO > SA1->A1_HASTA
				Aviso( OemToAnsi(STR0004), OemToAnsi(STR0365), {STR0028} )
				lRet := .F.
			EndIf
		Else
			Aviso( OemToAnsi(STR0004), OemToAnsi(STR0366), {STR0028} )
			lRet := .F.
		EndIf
	Else
		M->LQ_ADIC5  := Space(TamSX3("LQ_ADIC5")[1])
		M->LQ_ADIC61 := Space(TamSX3("LQ_ADIC61")[1])
		M->LQ_ADIC62 := Space(TamSX3("LQ_ADIC62")[1])
		M->LQ_ADIC7  := Space(TamSX3("LQ_ADIC7")[1])
	EndIf

Return(lRet)


/*/
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    Lj7AtuBrw	³ Autor ³ Vendas Cliente        ³ Data ³02/11/2015³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Funcao que atualiza a Mbrowse da tela de orcamentos de  	  ³±±
±±³          ³ acordo com a configuracao do parametro MV_LJBW701.    	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Retorno   ³ Nil             											  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso       ³ SIGALOJA                                                   ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
/*/
Static Function Lj7AtuBrw()
LjMsgRun( "Atualizando informações..." ,, { || Lj7Refresh( GetObjBrow(), Nil ), Sleep(1000)} )
Return NIL

/*/
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    |LjSalvaVda| Autor ³ Vendas Cliente        ³ Data ³02/11/2015³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Funcao que atualiza a Mbrowse da tela de orcamentos de  	  ³±±
±±³          ³ acordo com a configuracao do parametro MV_LJBW701.    	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Retorno   ³ Nil             											  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso       ³ SIGALOJA                                                   ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
/*/
Static Function LjSalvaVda(	cAlterCond	, lLog1		, lPrcBonus	, nOpc		, lTefPendCS	,;
							aTefBKPCS	, aBonus	, nSaveSX8	, lSair		, aDocDev		,;
							lLJDTOrc	, nVlrAcrsFi, cSigEspFo	, cDocFo	, aDadosCNeg	,;
							lErroNFCe	, lErroNFe )

//aCols
Local lContinua	 	:= .T.
Local aCloaCols   	:= {}
Local nHandle     	:= -1
Local cLjArq      	:= Space(8)
Local cImpressora 	:= LjGetStation("IMPFISC")
local cPorta	  	:= LJGetStation("PORTIF")
Local lCenVenda		:= SuperGetMv("MV_LJCNVDA",,.F.)										// Indica se existe integracao com cenario de vendas

If !lPressedF5 .And. LjKeyFuncs(2)       
	lPressedF5 := .T.
		
    If !lAutoExec
    	//Valida permissao para utilizar orcamento em uso
        If !FR271CVldImp(SL1->L1_NUM, .T.)
            If MsgNoYes(STR0240 + SL1->L1_NUM + STR0432, STR0015) //" foi importado em outro Ponto de Venda, necessária autorização do superior, deseja continuar?"
                If LjProfile(43)
                    LjxCDelArq(SL1->L1_NUM, .T.)
                Else
                    lContinua := .F.
                EndIf
            Else
                lContinua := .F.
            EndIf
        EndIf
        
        //Valida se Ncc foi baixada por outro processo
        If lContinua 
            lContinua := Lj7VldNCC(nOpc, .T.)            
        EndIf
    EndIf

	If lContinua .And. ((nOpc == 4 .AND. IsInCallStack("LjNFCeLot")) .Or. ( (lRecebe .Or. Lj701VRegD("SA1") ) .AND. Lj701VRegD("SA3") .AND. Lj701VRegD("SE4") .AND. LjPerDro(aCols)))
		If Lj7SetKeys()
			Lj7AtuPgto(cAlterCond)
			If lLog1
				aCloaCols := aClone(aCols)
				LJGrLog(@nHandle, M->LQ_NUM, @cLJArq, cImpressora, cPorta)
			EndIf
			If lCenVenda .AND. !lPrcBonus .AND. !lAutoExec
				LjMsgRun(STR0142,,{|| LJ7Bonus(nOpc,@lTefPendCS,@aTefBKPCS,@aBonus), lPrcBonus := .T. } ) // Processando bonificação
			EndIf
			
			If nOpc <> 2
				LJ7Gravacao(2			, nOpc		, nSaveSX8		, @lSair		,;
				 			nHandle		, aDocDev	, lLJDTOrc		, @lTefPendCS	,;
				 			@aTefBKPCS	, Nil		, M->LQ_TPFRET	, nVlrAcrsFi	,;
				 			cSigEspFo	, cDocFo	, aDadosCNeg	, @lErroNFCe	,;
				 			@lErroNFe	)
			EndIf
			
			If lLog1
				LJDelLog(nHandle	, aCloaCols		, aCols			, cLJArq	,;
						M->LQ_NUM	, M->LQ_DESCONT	, M->LQ_CLIENTE	,M->LQ_LOJA	)
			EndIf
			
			If lSair .And. lCenVenda .AND. Len(aBonus)>0
				LjTelaBon(@aBonus)
			EndIf
			
			If lSair .AND. Type("oDlgVA") <> "U"
				oDlgVA:End()
			EndIf
		EndIf
	EndIf
	lPressedF5 := .F.
EndIf

Return

/*/
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    |Lj7IsNoFun| Autor ³ Varejo                ³ Data ³28/03/2016³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Verifica se eh uma funcao que deve ser desabiitada.     	  ³±±
±±³          ³ Esaa funcao trabalha em conjunto com o PE "LJNoFunc".      ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Retorno   ³ lRet = .T.=Deve desabilitar funcao.                        ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso       ³ SIGALOJA                                                   ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
/*/
Function Lj7IsNoFun(nNumFunc)
Local lRet 	:= .F.

If aScan( aNoFuncs, nNumFunc ) > 0
	lRet := .T.
EndIf

Return lRet

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³ IntegDef  ³ Autor ³ Vendas Cliente       ³ Data ³ 05/01/16 	³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Rotina para Definicao de Integracao via Mensagem Unica.    	³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ IntegDef(cXml, cTypeTran, cTypeMsg)			             	 	³±±
±±³          ³ aExp1 - Conteudo da mensagem (XML)    							³±±
±±³          ³ aExp2 - Tipo da transacao                             	  		³±±
±±³          ³ aExp3 - Tipo da mensagem          		            	   		³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Retorno	  ³ Aray com resultado da execucao e a mensagem Xml de retorno.	³±±
±±³          ³ aRet[1]-(boolean) Indica o resultado da execução da função		³±±
±±³          ³ aRet[2]-(caracter) Mensagem Xml para envio                		³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701 																³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function IntegDef( xEnt, nTypeTrans, cTypeMessage , cVersion, cTransaction, lJSon )

Local aRet := {}

Lj701StInD( .T. )
aRet := LOJI701(xEnt, nTypeTrans, cTypeMessage,lJSon)

Lj701StInD( .F. )

Return aRet

//-------------------------------------------------------------------
/*/{Protheus.doc} Lj7CopOrc
@description Funcao para criar um novo orcamento a partir de um existente
@author Rene Julian
@since 27/07/2016
@version 11.80
/*/
//-------------------------------------------------------------------
Function Lj7CopOrc(cAlias,nReg , nOpc )
Local nX		:= 0  // Usado para Auxiliar o For
Local aCpASLQ  := {} // Campos para o Cabecario
Local aCpASLR  := {} // Campos para os itens do Orcamento
Local aCpASL4  := {} // Campos para as formas de pagamento
Local cTexto   := "Confirma Geração do novo orçamento"
Local cTitulo  := "Copia de Orçamento"
Local cInfo    := "Aguarde Gerando Orcamento"

Private lAutomato := If(Type("lAutomatoX")<>"L",.F.,lAutomatoX)

SX3->(DbSetOrder(1))
SX3->(DbSeek("SLQ"))
While !Eof() .AND. SX3->X3_ARQUIVO == "SLQ"
	If X3Uso(SX3->X3_USADO) .And. SX3->X3_CONTEXT <> "V"
		If SL1->(ColumnPos("L1_" + SubStr(Trim(SX3->X3_CAMPO),4))) > 0 //So considera o campo se ele existir tambem na tabela SL1.
			AAdd(aCpASlQ,Trim(SX3->X3_CAMPO))
		EndIf
	EndIf
	SX3->(DbSkip())
End

SX3->(DbSeek("SLR"))
While !Eof() .AND. SX3->X3_ARQUIVO == "SLR"
	If X3Uso(SX3->X3_USADO) .And. SX3->X3_CONTEXT <> "V"
		If SL2->(ColumnPos("L2_" + SubStr(Trim(SX3->X3_CAMPO),4))) > 0 //So considera o campo se ele existir tambem na tabela SL2.
			AAdd(aCpASLR,Trim(SX3->X3_CAMPO))
		EndIf
	EndIf
	SX3->(DbSkip())
End

SX3->(DbSeek("SL4"))
While !Eof() .AND. SX3->X3_ARQUIVO == "SL4"
	If X3Uso(SX3->X3_USADO) .AND. SX3->X3_CONTEXT <> "V"
		AAdd(aCpASL4,Trim(SX3->X3_CAMPO))
	EndIf
	SX3->(DbSkip())
End

If !lAutomato	
	If MsgYesNo( cTexto, cTitulo )
		LjMsgRun(cInfo,,{|| Lj7CpGrvOr(aCpASLQ, aCpASLR , aCpASL4,cAlias , nOpc ) } )
	EndIf
Else
	Lj7CpGrvOr(aCpASLQ, aCpASLR , aCpASL4,cAlias , nOpc )
Endif

Return .T.

//-------------------------------------------------------------------
/*/{Protheus.doc} Lj7CpGrvOr
@description Funcao para gravar o novo orcamento
@author Rene Julian
@since 27/07/2016
@version 11.80
/*/
//-------------------------------------------------------------------
Function Lj7CpGrvOr(aCpASLQ,aCpASLR , aCpASL4,cAlias, nOpc )
Local cNewNum  := ""//GetSxeNum( "SL1", "L1_NUM" )
Local nX 	   := 0
Local cChvSL2  := ""
Local nItSL2   := 0
Local nValTot  := 0
Local aCabOrc  := {}
Local aITsOrc  := {}
Local aSL4Orc  := {}
Local aCpASL1  := SL1->(DbStruct())  // Campos para o Cabecario - validação dos campos da SL1 no SX3
Local nNewReg  := 0
Local nOpcX    := 4
Local nMVDtlimit := SuperGetMV("MV_DTLIMIT") // Variavel auxiliar para receber o conteudo do parametro MV_DTLIMIT
Local lPedRes  := SL1->(ColumnPos("L1_PEDRES")) > 0 //Verifica se existe o Campo "L1_PEDRES"
Local aSLQDesc := {}//Campos da SLQ a serem desconsiderados na copia de Orcamentos  
Local aSLRDesc := {}//Campos da SLR a serem desconsiderados na copia de Orcamentos
Local lLj7106  := ExistBlock("LJ7106")// responsavel por permitir, a exclusãode campos na copia de orcamento
Local aLj7106  := {}// responsavel por permitir, a exclusãode campos na copia de orcamento

Private lMsErroAuto := .F.

aAdd(aSLQDesc ,  "LQ_NUM")    ; aAdd(aSLQDesc ,  "LQ_DOC")    ; aAdd(aSLQDesc ,  "LQ_SERIE")  ; aAdd(aSLQDesc ,  "LQ_PDV")
aAdd(aSLQDesc ,  "LQ_EMISNF") ; aAdd(aSLQDesc ,  "LQ_DVOSORI"); aAdd(aSLQDesc ,  "LQ_DINHEIR"); aAdd(aSLQDesc ,  "LQ_CHEQUES")
aAdd(aSLQDesc ,  "LQ_HORCANC"); aAdd(aSLQDesc ,  "LQ_NUMORIG"); aAdd(aSLQDesc ,  "LQ_VENDTEF"); aAdd(aSLQDesc ,  "LQ_DATATEF")
aAdd(aSLQDesc ,  "LQ_HORATEF"); aAdd(aSLQDesc ,  "LQ_DOCTEF") ; aAdd(aSLQDesc ,  "LQ_AUTORIZ"); aAdd(aSLQDesc ,  "LQ_DOCCANC")
aAdd(aSLQDesc ,  "LQ_DATCANC"); aAdd(aSLQDesc ,  "LQ_NSUTEF") ; aAdd(aSLQDesc ,  "LQ_TIPCART"); aAdd(aSLQDesc ,  "LQ_ADMFIN")
aAdd(aSLQDesc ,  "LQ_TIPOJUR"); aAdd(aSLQDesc ,  "LQ_CARTAO") ; aAdd(aSLQDesc ,  "LQ_CARTFID"); aAdd(aSLQDesc ,  "LQ_SEGURO" )
aAdd(aSLQDesc ,  "LQ_CREDITO"); aAdd(aSLQDesc ,  "LQ_SITUA")  ; aAdd(aSLQDesc ,  "LQ_VALICM") ; aAdd(aSLQDesc ,  "LQ_VALIPI")
aAdd(aSLQDesc ,  "LQ_PRODUTO"); aAdd(aSLQDesc ,  "LQ_RESERVA"); aAdd(aSLQDesc ,  "LQ_DESCONT"); aAdd(aSLQDesc ,  "LQ_DESCNF")
aAdd(aSLQDesc ,  "LQ_DESCFIN"); aAdd(aSLQDesc ,  "LQ_TPFRET") ; aAdd(aSLQDesc ,  "LQ_FRETE")  ; aAdd(aSLQDesc ,  "LQ_DESPESA")
aAdd(aSLQDesc ,  "LQ_SERSAT") ; aAdd(aSLQDesc ,  "LQ_NUMORC")
	            
If lPedRes
    aAdd(aSLQDesc, "LQ_PEDRES")
EndIf    

aAdd(aSLRDesc , "LR_NUM" )   ; aAdd(aSLRDesc , "LR_PRODUTO"); aAdd(aSLRDesc , "LR_ITEM" )  ; aAdd(aSLRDesc , "LR_DOC")    ; aAdd(aSLRDesc , "LR_SERIE") 
aAdd(aSLRDesc , "LR_PDV")    ; aAdd(aSLRDesc , "LR_STATUS") ; aAdd(aSLRDesc , "LR_NSERIE") ; aAdd(aSLRDesc , "LR_CODITE") ; aAdd(aSLRDesc , "LR_RESERVA")
aAdd(aSLRDesc , "LR_LOJARES"); aAdd(aSLRDesc , "LR_PEDFAT") ; aAdd(aSLRDesc , "LR_VALFRE") ; aAdd(aSLRDesc , "LR_SEGURO") ; aAdd(aSLRDesc , "LR_DESPESA")
aAdd(aSLRDesc , "LR_NUMLAY") ; aAdd(aSLRDesc , "LR_ITEMLAY"); aAdd(aSLRDesc , "LR_EMPRES") ; aAdd(aSLRDesc , "LR_FILRES") ; aAdd(aSLRDesc , "LR_ORCRES")
aAdd(aSLRDesc , "LR_ALIQPS2"); aAdd(aSLRDesc , "LR_ITEMSD1"); aAdd(aSLRDesc , "LR_FDTENTR"); aAdd(aSLRDesc , "LR_CODCONT"); aAdd(aSLRDesc , "LR_FDTMONT")
aAdd(aSLRDesc , "LR_NUMORIG"); aAdd(aSLRDesc , "LR_VALEPRE"); aAdd(aSLRDesc , "LR_ESPECIE"); aAdd(aSLRDesc , "LR_ALIQCF2"); aAdd(aSLRDesc , "LR_PEDSC5")
aAdd(aSLRDesc , "LR_ITESC6") ; aAdd(aSLRDesc , "LR_SEQUEN") ; aAdd(aSLRDesc , "LR_SOLCOM") ; aAdd(aSLRDesc , "LR_SERPDV") ; aAdd(aSLRDesc , "LR_CONTDOC")
aAdd(aSLRDesc , "LR_PAFMD5") ; aAdd(aSLRDesc , "LR_CODLPRE"); aAdd(aSLRDesc , "LR_GARANT") ; aAdd(aSLRDesc , "LR_ITLPRE") ; aAdd(aSLRDesc , "LR_MSMLPRE")
aAdd(aSLRDesc , "LR_MSGLPRE"); aAdd(aSLRDesc , "LR_REMLPRE"); aAdd(aSLRDesc , "LR_REVLPRE"); aAdd(aSLRDesc , "LR_NUMCFID"); aAdd(aSLRDesc , "LR_MESREC")
aAdd(aSLRDesc , "LR_DTSDFID"); aAdd(aSLRDesc , "LR_VLRCFID"); aAdd(aSLRDesc , "LR_PROCFID"); aAdd(aSLRDesc , "LR_ITEMNF") ; aAdd(aSLRDesc , "LR_VALACRS")
aAdd(aSLRDesc , "LR_VLGAPRO"); aAdd(aSLRDesc , "LR_BLEST")  ; aAdd(aSLRDesc , "LR_TOTIMP") ; aAdd(aSLRDesc , "LR_ALQIMP2"); aAdd(aSLRDesc , "LR_VDMOST")
aAdd(aSLRDesc , "LR_DESC")   ; aAdd(aSLRDesc , "LR_DESCORC"); aAdd(aSLRDesc , "LR_DESCPRO"); aAdd(aSLRDesc , "LR_VALICM") ; aAdd(aSLRDesc , "LR_VALIPI")
aAdd(aSLRDesc , "LR_VRUNIT") ; aAdd(aSLRDesc , "LR_VALDESC"); aAdd(aSLRDesc , "LR_VLRITEM"); aAdd(aSLRDesc , "LR_DESCRI") 

//P.E - Permite informar quais campos que não deseja copiar no orçamento
If lLj7106
	LjGrvLog( NIL, "Antes da execução do PE LJ7106",{aSLQDesc, aSLRDesc})
    aLj7106 := ExecBlock("LJ7106",.F.,.F., {aSLQDesc, aSLRDesc})
    LjGrvLog( NIL, "Retorno da execução do PE LJ7106",aLj7106)
    
    If Valtype(aLj7106) <> "A" .Or. Len(aLj7106) <> 2
        aLj7106 := {}
    ElseIf Len(aLj7106) == 2
        aSLQDesc := aClone(aLj7106[1])
        aSLRDesc := aClone(aLj7106[2])
    EndIf
EndIf

For nX := 1 To Len(aCpASLQ)
    If !(Ascan(aSLQDesc,{|x| Alltrim(x) == AllTrim(aCpASLQ[nX])}) > 0)
        If AllTrim(aCpASLQ[nX]) == "LQ_DTLIM"
            AAdd(aCabOrc,{aCpASLQ[nX], dDataBase + IIF(nMVDtlimit != 0, nMVDtlimit, 0), Nil })
        ElseIf AllTrim(aCpASLQ[nX]) == "LQ_EMISSAO"
            AAdd(aCabOrc,{aCpASLQ[nX], dDataBase, Nil })
        ElseIf AllTrim(aCpASLQ[nX]) == "LQ_CONDPG"
            AAdd(aCabOrc,{aCpASLQ[nX], SuperGetMV("MV_CONDPAD"), Nil })            
        Else
            AAdd(aCabOrc,{aCpASLQ[nX], &("SL1->L1_" + SubStr(aCpASLQ[nX],4,Len(aCpASLQ[nX]))) , Nil })
        EndIf
    EndIf
Next nX	      

//Tratamento copia itens
SL2->(DbSetOrder(1))
SL2->(DbSeek(xFilial("SL2") + SL1->L1_NUM))
cChvSL2 := xFilial("SL2") + SL2->L2_NUM
While !SL2->(EOF()) .And. cChvSL2 == xFilial("SL2") + SL2->L2_NUM
    If nItSL2 <> Val(SL2->L2_ITEM)
        AAdd(aITsOrc,{{"LR_PRODUTO", Alltrim(SL2->L2_PRODUTO)  , Nil }})
    EndIf
    nITSL2 := Len(aITsOrc)
    For nX := 1 To Len(aCpASLR)
       If !(Ascan(aSLRDesc,{|x| Alltrim(x) == AllTrim(aCpASLR[nX])}) > 0)
           If AllTrim(aCpASLR[nX]) == "LR_VRUNIT" // pego o preco de tabela por causa do Desconto
               AAdd(aITsOrc[nITSL2],{aCpASLR[nX], SL2->L2_PRCTAB , Nil })
           ElseIf AllTrim(aCpASLR[nX]) == "LR_VLRITEM"
               AAdd(aITsOrc[nITSL2],{aCpASLR[nX],SL2->L2_QUANT * SL2->L2_PRCTAB  , Nil })
           ElseIf AllTrim(aCpASLR[nX]) == "LR_ENTREGA"
               AAdd(aITsOrc[nITSL2],{aCpASLR[nX], "2" , Nil })
           Else
		   	   If ValType(&("SL2->L2_" + SubStr(aCpASLR[nX],4,Len(aCpASLR[nX])))) <> 'C' .Or.; 
				 (ValType(&("SL2->L2_" + SubStr(aCpASLR[nX],4,Len(aCpASLR[nX])))) == 'C' .And.;
			     !Empty(&("SL2->L2_" + SubStr(aCpASLR[nX],4,Len(aCpASLR[nX])))))   // nao enviar os campos caracter que estao sem conteudo
              		 AAdd(aITsOrc[nITSL2],{aCpASLR[nX], &("SL2->L2_" + SubStr(aCpASLR[nX],4,Len(aCpASLR[nX]))) , Nil })
				Endif
           EndIf
       EndIf    
    Next nX
    nValTot += SL2->L2_QUANT * SL2->L2_PRCTAB //Quando ha mais de um item na venda a soma deve ser feita por item
    SL2->(DbSkip())
EndDo

//Monta o cabeçalho do orçamento (aPagtos)
aAdd(aSL4Orc,{;
   {"L4_DATA"		, dDatabase					,NIL},;
   {"L4_VALOR"		, nValTot					,NIL},;
   {"L4_FORMA"		, "R$             "    		,NIL},;
   {"L4_ADMINIS"	, Space(20)					,NIL},;
   {"L4_FORMAID"	, Space(1)         			,NIL},;
   {"L4_MOEDA"		,  0          				,NIL}})

   ConOut("Start ExecAuto LOJA701 - Copia de Orcamento")
   LjGrvLog( NIL, "Start ExecAuto LOJA701 - Copia de Orcamento")
   Begin Transaction
        
        ConOut("Antes da Chamada da ExecAuto LOJA701 - Copia de Orcamento")
        LjGrvLog( NIL, "Antes da Chamada da ExecAuto LOJA701 - Copia de Orcamento - Dados [SL1/SL2/SL4]",{aCabOrc,aITsOrc,aSL4Orc})
        
        MSExecAuto({|a,b,c,d,e,f,g,h| Loja701(a,b,c,d,e,f,g,h)},.F.,3,"","",{},aCabOrc,aITsOrc,aSL4Orc)
        
        ConOut("Depois da Chamada da ExecAuto LOJA701 - Copia de Orcamento")
        LjGrvLog( NIL, "Depois da Chamada da ExecAuto LOJA701 - Copia de Orcamento")
   
        If lMsErroAuto
        	MostraErro()
        	LjGrvLog( NIL,"Erro da ExecAuto LOJA701 - Copia de Orçamento - Erro: " +;
        	 			CHR(10) + CHR(13) + MostraErro())
            RollBackSX8()
        Else
            nNewReg := SL1->(RECNO())
            ConfirmSX8()        
	        
	        If !lAutomato //Apresento o novo registro para visualizacao
	        	LjGrvLog( NIL, "Antes da Chamada da Lj7Venda - Copia de Orcamento",{nNewReg,nOpcX})
	        	Lj7Venda(cAlias, nNewReg, nOpcX)
	        	LjGrvLog( NIL, "Depois da Chamada da Lj7Venda - Copia de Orcamento")
	        EndIf 	        
       EndIf
       
   End Transaction
   
   LjGrvLog( NIL, "End ExecAuto LOJA701 - Copia de Orcamento")
Return

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³LjNFCeLot ºAutor  ³TOTVS IP SOROCABA   º Data ³  10/03/16   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Rotina de finalização de orçamento NFCE em Lote.            º±±
±±º          ³                                                            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ AP                                                         º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function LjNFCeLot()
Local cPerg         := PadR("NFCELOTE", Len(SX1->X1_GRUPO))
Local aArea         := GetArea()

Private aList       := {}                           //Array contendo os orçamentos que não foram finalizados
Private aOrcsLot    := {}

If Pergunte(cPerg, .T.)
    Processa( {|| SelorcLot(MV_PAR01, MV_PAR02, MV_PAR03, MV_PAR04, MV_PAR05)}, STR0006, STR0397, .F.) //"Orçamento", "Processando aguarde..."
Endif
    
RestArea(aArea)

Return

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³SelorcLot ºAutor  ³TOTVS IP SOROCABA   º Data ³  10/03/16   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³nOpc == 1 - Seleciona automaticamente os orcamentos a serem º±±
±±º          ³finalizados em Lote como NFCE.                              º±±
±±º          ³nOpc == 2 - Apresenta tela de selecao de orcamentos para    º±±
±±º          ³finalização em Lote de NFCE.                                º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ AP                                                         º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function SelorcLot(nOpcao, dDtDe, dDtAte, cNumIni, cNumFim)

Local oDlgOrc           := Nil
Local _cAlias           := GetNextAlias()
Local aItems            := {STR0006,STR0046} //"Orçamento","Cliente"
Local cCombo            := ""
Local cTxtPesquisa      := SPACE(100)
Local cCampos		   := "L1_NUM,L1_CLIENTE,L1_LOJA,A1_NOME"
Local aCampos           := StrTokArr( cCampos, "," )
Local aCpo              := {}
Local nX                := 0
Local aBrowse           := {}
Local oBrowse           := nil
Local oOK               := LoadBitmap(GetResources(),'LBOK')
Local oNO               := LoadBitmap(GetResources(),'LBNO')
Local cQuery            := ""
Local cWhere            := ""
Local cOrder            := ""
Local cFilQry           := ""
Local aDados            := {}
Local lLJ7105		   := 	ExistBlock("LJ7105")

Local aStruSLQ    		:= SLQ->(dbStruct())
Local aStruSLR    		:= SLR->(dbStruct())
Local aStruSL4    		:= SL4->(dbStruct())    
    
    If nOpcao == 2

        DEFINE MSDIALOG oDlgOrc TITLE STR0403 FROM  AjusTela(249), AjusTela(331) TO  AjusTela(500), AjusTela(800) PIXEL //Selecionar Orçamentos"

        TComboBox():New(AjusTela(002),AjusTela(002),{|u|if(PCount()>0,cCombo:=u,cCombo)},aItems,080,20,oDlgOrc,,{|| cTxtPesquisa := SPACE(100),.T. },,,,.T.,,,,,,,,,'cCombo')
        TGet():New(AjusTela(002), AjusTela(067), bSetGet(cTxtPesquisa), oDlgOrc, 157, 008, "@!",,,,,,,.T.,,,{|| .T.})
        TButton():New(AjusTela(001), AjusTela(195), STR0002 ,oDlgOrc,{|| PosItem(cTxtPesquisa,cCombo,oBrowse) }, AjusTela(037), AjusTela(010),,,.F.,.T.,.F.,,.F.,,,.F. ) //"Pesquisar"  

        oBrowse := TCBrowse():New( AjusTela(012),AjusTela(002), AjusTela(235), AjusTela(100),,,{50,50,50},oDlgOrc,,,,,{||},,,,,,,.F.,,.T.,,.F.,,, )

        aBrowse := CarrLotOrc(cNumIni, cNumFim, dDtDe, dDtAte, cCampos, aCampos, lLJ7105)
        oBrowse:SetArray(aBrowse)

        oBrowse:AddColumn(TCColumn():New('',{||if(aBrowse[oBrowse:nAt,1],oOk,oNo) }  ,,,,,,.T.,.F.,,,,.F.,))
        
        For nX := 1 to len(aCampos)
            SX3->(DbSetOrder(2))
            SX3->(DbSeek(aCampos[nX]))
            nPosCpo := nX+1

            oBrowse:AddColumn(TCColumn():New(X3TITULO(aCampos[nX]),&("{|| aBrowse[oBrowse:nAt," + cValToChar(nPosCpo) + "]}"),,,,"LEFT",,.F.,.F.,,,,.F.,))
        Next nX
        
        oBrowse:lUseDefaultColors := .F.

        oBrowse:bHeaderClick := {|o,x| markAll(oBrowse) , oBrowse:refresh()}
        oBrowse:bLDblClick   := {|z,x| aBrowse[oBrowse:nAt,1] :=  !aBrowse[oBrowse:nAt,1] }

        @  AjusTela(114), AjusTela(155) Button "&Confirmar" ACTION (Processa( {|| EnvOrcSel(oBrowse, oDlgOrc, aStruSLQ, aStruSLR, aStruSL4)} , STR0006, STR0397, .F.)) Size  AjusTela(037), AjusTela(011) PIXEL OF oDlgOrc //"Orçamento", "Processando aguarde..."
        @  AjusTela(114), AjusTela(195) Button "&Cancelar"  ACTION (oDlgOrc:End())  Size  AjusTela(037), AjusTela(011) PIXEL OF oDlgOrc

        ACTIVATE MSDIALOG oDlgOrc CENTERED
    Else
    
        cQuery  := " SELECT"
        cQuery  += " L1_NUM"
        cQuery  += " FROM " + RetSqlName("SL1") + " SL1"
        
        cWhere  := " WHERE"
        cWhere  += " SL1.L1_FILIAL = '"       + xFilial('SL1') + "' AND"
        cWhere  += " SL1.L1_NUM BETWEEN '"     + cNumIni       + "' AND '" + cNumFim      + "' AND"
        cWhere  += " SL1.L1_EMISSAO BETWEEN '" + Dtos(dDtDe)    + "' AND '" + Dtos(dDtAte) + "' AND"
        cWhere  += " SL1.L1_DOC = ' ' AND SL1.D_E_L_E_T_ = ' ' "
        
        cOrder  := " ORDER BY SL1.L1_FILIAL,SL1.L1_NUM,SL1.L1_CLIENTE,SL1.L1_LOJA"
        
        If lLJ7105// responsavel por permitir, a inclusao de filtro customizado para a NFCELote
	        cFilQry := AllTrim(ExecBlock("LJ7105", .F., .F., { cWhere }))
	        If Valtype(cFilQry) <> "C"
	            cFilQry := ""
	            LjGrvLog("", "NFCELote - Retorno diferente de Caracter do P.E LJ7105, logo a query sera executada conforme padrao.", cQuery + cWhere + cOrder)
	            MsgInfo("NFCELote - O tipo de retorno do ponto de entrada LJ7105 é diferente de Caracter , desta forma o ponto de entrada sera desconsiderado no processamento.")
	        ElseIf !Empty(cFilQry)	
	        	cFilQry := " AND (" + cFilQry + " )"	        	
	        	If TCSQLEXEC(cQuery + cWhere + cFilQry + cOrder) >= 0 //Verifica se nao ira gerar error.log o filtro retornado pelo P.E.         	        
			        cWhere += cFilQry
			        LjGrvLog("", "NFCELote - Query a ser executada com inclusão de filtro passado via P.E LJ7105.", cQuery + cWhere + cOrder)
			    Else  
			    	LjGrvLog("", "NFCELote - O Filtro retornado pelo ponto de entrada LJ7105 gerou erro na query, por isso a mesma sera executada conforme o padrao.", TCSQLError())		    	   
			    EndIf    
		    Endif
	    EndIf
        
        cQuery :=   ChangeQuery(cQuery + cWhere + cOrder)

        dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQuery), _cAlias,.F.,.T.)

        ProcRegua( (_cAlias)->(RecCount()) + 1)

        (_cAlias)->(DbGotop())
        (_cAlias)->(DbEval( {|| aAdd(aDados, (_cAlias)->L1_NUM )  } ) ) // Adiciono os orçamentos selecionados ao array aDados
        
        If Len(aDados) > 0 
        
            SetOrcSel(aDados)//Alimento variavel publica com os orçamentos selecionados para possivel utilização destes dados em P.E
            
            (_cAlias)->(DbGotop())
            While (_cAlias)->(!Eof())
                
                NFCEEnv((_cAlias)->L1_NUM, aStruSLQ, aStruSLR, aStruSL4)
                
                (_cAlias)->(DbSkip())
            EndDo           
        EndIf           
    EndIf

    If Len( aList ) > 0
        ListNFCerr()
    Endif

Return

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Markall   ºAutor  ³TOTVS IP SOROCABA   º Data ³  10/03/16   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Rotina de Marca ou desmarca.  							   º±±
±±º          ³						                                  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ AP                                                         º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function Markall(oObj)

Local nI := 0
Local nMarks := 0

    For nI := 1 to Len(oObj:aArray)
        if oObj:aArray[nI,1]
            nMarks++
        endIf
    Next nI

    For nI := 1 to Len(oObj:aArray)
        oObj:aArray[nI,1] := (nMarks < Len(oObj:aArray))
    Next nI
    
    oObj:refresh()

Return
/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³EnvOrcSel ºAutor  ³TOTVS IP SOROCABA   º Data ³  10/03/16   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Rotina para envio dos orcamentos selecionados para a rotina º±±
±±º          ³de finalizacao de orcamentos em Lote NFCE (NFCEEnv).        º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ AP                                                         º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function EnvOrcSel(oObj, oBjTela, aStruSLQ, aStruSLR, aStruSL4)

Local nX        := 0
Local nTotReg   := 0
Local aDados    := {}
Local nPos      := 0    
    
    nPos := aScan(oObj:aArray, { | x | x[1] == .T. } )

    If nPos > 0
        nTotReg := Len(oObj:aArray)
        
        For nX := 1 to nTotReg
    
            If oObj:aArray[nX][1]
                aAdd(aDados, oObj:aArray[nX][2])           
            EndIf    
        
        Next nX
        
        SetOrcSel(aDados)
        nTotReg := Len(aDados)    
    
        For nX := 1 to nTotReg

            NFCEEnv(aDados[nX], aStruSLQ, aStruSLR, aStruSL4)
        Next nX
        
        oBjTela:End()
    Else
        MsgInfo(STR0404,STR0405) //"Não foi selecionado nenhum orçamento!","Seleção de Orçamento"
    EndIf

Return

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³SetOrcSel ºAutor  ³TOTVS IP SOROCABA   º Data ³  10/03/16   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Rotina criada para auxiliar na customizacao dos orcamentos  º±±
±±º          ³selecionados para  finalização e NFCE em Lote.              º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ AP                                                         º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function SetOrcSel(aOrcs)
    
    If aOrcsLot != Nil
        aOrcsLot := aOrcs
    EndIf    
Return aOrcsLot

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³NFCEEnv   ºAutor  ³TOTVS IP SOROCABA   º Data ³  10/03/16   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Rotina que faz a finalização de orcamentos NFCE em Lote.    º±±
±±º          ³                                                            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ AP                                                         º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function NFCEEnv(cNumOrc, aStruSLQ, aStruSLR, aStruSL4)

Local aArea     := GetArea()
Local aSL1Area  := SL1->(GetArea())
Local aSL2Area  := SL2->(GetArea())
Local aSL4Area  := SL4->(GetArea())
Local aSx3Area  := SX3->(GetArea())
Local _aCab     := {}                           //Array do Cabeçalho do Orçamento
Local _aItem    := {}                           //Array dos Itens do Orçamento
Local _aParcela := {}                           //Array das Parcelas do Orçamento
Local nOpc      := 4                           //Tipo de operacao (3=Inclusao; 4=Alteracao; 5=Exclusao)
Local nX        := 0
Local nIt       := 0
Local lPermForm  := .T.
Local cCampo		:= .T.

Private lMsHelpAuto   := .T.                    //Variavel de controle interno do ExecAuto
Private lMsErroAuto   := .F.                    //Variavel que informa a ocorrência de erros no ExecAuto
Private INCLUI       := .T.                    //Variavel necessária para o ExecAuto identificar que se trata de uma inclusão
Private ALTERA       := .F.                    //Variavel necessária para o ExecAuto identificar que se trata de uma inclusão

    dbSelectArea('SX3')
    SX3->( dbSetOrder(2) )

    dbSelectArea("SL1")
    SL1->(dbSetOrder(1))    
    If SL1->(DbSeek(xFilial("SL1") + cNumOrc))
    
        For nX := 1 To Len(aStruSLQ)   
        	cCampo := "L1_" + SubStr(aStruSLQ[nX][1], 4, Len(aStruSLQ[nX][1]))
            If SX3->( dbSeek( cCampo )) .And. SX3->X3_CONTEXT != "V" .And. !Empty( SL1->&( cCampo ))          
                Do Case        
                    Case Alltrim(aStruSLQ[nX][1]) == "LQ_EMISSAO"
                        aAdd(_aCab, {aStruSLQ[nX][1], dDataBase , NIL} )                          
                    OtherWise
                        aAdd(_aCab, {aStruSLQ[nX][1], SL1->&( cCampo ), NIL} )            
                EndCase
            EndIf    
        Next nX
        
        dbSelectArea("SL2")
        SL2->(dbSetOrder(1))
        SL2->(DbSeek(xFilial("SL2") + SL1->L1_NUM))
        
        nIt := 0        
        While !SL2->(Eof()) .And. xFilial("SL2") + SL1->L1_NUM == SL2->L2_FILIAL + SL2->L2_NUM            
            nIt++   
            aAdd(_aItem, {})         
            For nX := 1 To Len(aStruSLR)
            	cCampo := "L2_" + SubStr(aStruSLR[nX][1], 4, Len(aStruSLR[nX][1]))            	                
                If SX3->( dbSeek( cCampo )) .And. SX3->X3_CONTEXT != "V" .And. !Empty( SL2->&( cCampo ))                    
					aAdd(_aItem[nIt], {aStruSLR[nX][1], SL2->&( cCampo ), NIL} ) 
                EndIf                     
            Next nX                     
            SL2->(dbSkip())
        EndDo            
        
        dbSelectArea("SL4")
        SL4->(dbSetOrder(1))
        SL4->(DbSeek(xFilial("SL4") + SL1->L1_NUM))
        
        nIt := 0        
        While !SL4->(Eof()) .And. xFilial("SL4") + SL1->L1_NUM == SL4->L4_FILIAL + SL4->L4_NUM            
            nIt++
            aAdd(_aParcela, {})
            For nX := 1 To Len(aStruSL4)   
            	cCampo := "L4_" + SubStr(aStruSL4[nX][1], 4, Len(aStruSL4[nX][1]) )
                If !( Alltrim(SL4->L4_FORMA) $ "CH|CC|CD")                             
					aAdd(_aParcela[nIt], {aStruSL4[nX][1], SL4->&( cCampo ), NIL} )
                Else
                    lPermForm := .F.
                    Exit                        
                EndIf      
            Next nX            
            SL4->(dbSkip())
        EndDo    
        
        If !lPermForm //Caso entre as formas de pagamento houver CC, CH e CD, a venda não podera ser feita em Lote, pois sera necessário a execução do TEF
            MsgInfo(STR0418 + SL1->L1_NUM + STR0419 )// "Para utilização da geração em Lote de NFCE, não serão permitidas formas de pagamento iguais a CD ou CC. O orçamento: " + (_cAlias)->(L1_NUM) + ", deverá ser finalizado manualmente." )
            Return
        EndIf
              
        SetFunName("LOJA701")
        
        lMsHelpAuto := .T.
        lMsErroAuto := .F.
        
        Loja701(.F., nOpc, SL1->L1_CLIENTE, SL1->L1_LOJA, {}, _aCab, _aItem , _aParcela, .T.)
                            
        If lMsErroAuto
            AAdd(aList, {SL1->L1_FILIAL, SL1->L1_NUM, SL1->L1_SERIE } )
            MostraErro()
            RollBackSX8()
        Else
            ConfirmSX8()
        EndIf   
    EndIf

    RestArea(aArea)
    RestArea(aSL1Area)
    RestArea(aSL2Area)
    RestArea(aSL4Area)
    RestArea(aSX3Area)

Return

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³ListNFCerrºAutor  ³TOTVS IP SOROCABA   º Data ³  10/03/16   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Rotina de tratamento dos orcamentos que por algum motivo naoº±±
±±º          ³ foram finalizados.                                         º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ AP                                                         º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function ListNFCerr()

Local       oButton1        //Botão de Sair
Local       oListBox        //Objeto ListBox
Local       nListBox := 1   //Variavel utilizada na ListBox
Local       lRet:= .T.      //Retorno da função

Static      oDlg            //Objeto de Tela

    DEFINE MSDIALOG oDlg TITLE STR0407 FROM 000, 000  TO 400, 500 COLORS 0, 16777215 PIXEL //"Orçamentos Não Enviados"

    @ 013, 012 LISTBOX oListBox VAR nListBox Fields HEADER STR0408, STR0409, STR0410   SIZE 224, 154 OF oDlg COLORS 0, 16777215 PIXEL //"FILIAL","CUPOM", "SERIE"

    @ 175, 199 BUTTON oButton1 PROMPT "&Sair" ACTION(oDlg:End()) SIZE 037, 012 OF oDlg PIXEL

    oListBox:SetArray(aList)
    oListBox:bLine := { || { aList[oListBox:nAt,1], aList[oListBox:nAt,2], aList[oListBox:nAt,3]} }

    ACTIVATE MSDIALOG oDlg CENTERED

Return(lRet)

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³CarrLotOrcºAutor  ³TOTVS IP SOROCABA   º Data ³  10/03/16   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Carrega array de orçamentos a serem selecionados quando     º±±
±±º          ³opção de tela for selecionada.                              º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ AP                                                         º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function CarrLotOrc(cOrcIni, cOrcFim, dDtDe, dDtAte, cCampos, aCampos, lLJ7105)

Local aRet              := {}
Local aTemp             := {}
Local _cAlias           := "cQryOrcArray"
Local cQuery            := ""
Local cWhere            := ""
Local cOrder            := ""
Local cFilQry			:= ""
Local nX                := 0

    cQuery  := " SELECT " + cCampos
    cQuery  += " FROM "+ RetSqlName("SL1")  + " SL1"
    cQuery  += " INNER JOIN "+RetSqlTab("SA1")+" ON SL1.L1_CLIENTE = SA1.A1_COD AND SL1.L1_LOJA = SA1.A1_LOJA"
    cQuery  += " AND SA1.D_E_L_E_T_ = '' AND SA1.A1_FILIAL = '" + xFilial("SA1") + "'"
    
    cWhere  := " WHERE"
    cWhere  += " SL1.L1_FILIAL = '"           + xFilial('SL1')  + "'"
    cWhere  += " AND SL1.L1_NUM BETWEEN '"     + cOrcIni        + "' AND '" + cOrcFim + "'"
    cWhere  += " AND SL1.L1_EMISSAO BETWEEN '" + DTOS(dDtDe)     + "' AND '" + DTOS(dDtAte) + "'"
    cWhere  += " AND SL1.L1_DOC = ' ' AND SL1.D_E_L_E_T_ = ' '"
    
    cOrder  := " ORDER BY SL1.L1_FILIAL,SL1.L1_NUM,SL1.L1_CLIENTE,SL1.L1_LOJA"
    
    If lLJ7105// responsavel por permitir, a inclusao de filtro customizado para a NFCELote
        cFilQry := AllTrim(ExecBlock("LJ7105", .F., .F., { cWhere }))
        If Valtype(cFilQry) <> "C"
            cFilQry := ""
            LjGrvLog("", "NFCELote - Retorno diferente de Caracter do P.E LJ7105, logo a query sera executada conforme padrao.", cQuery + cWhere + cOrder)
            MsgInfo("NFCELote - O tipo de retorno do P.E LJ7105 é diferente de Caracter , desta forma o ponto de entrada sera desconsiderado no processamento.")
        ElseIf !Empty(cFilQry)	
	    	cFilQry := " AND (" + cFilQry + " )"	        	
	      	If TCSQLEXEC(cQuery + cWhere + cFilQry + cOrder) >= 0 //Verifica se nao ira gerar error.log o filtro retornado pelo P.E.         	        
		    	cWhere += cFilQry
			    LjGrvLog("", "NFCELote - Query a ser executada com inclusão de filtro passado via P.E LJ7105.", cQuery + cWhere + cOrder)
			Else  
				LjGrvLog("", "NFCELote - O Filtro retornado pelo P.E LJ7105 gerou erro na query, por isso a mesma sera executada conforme o padrao.", TCSQLError())
				MsgInfo("NFCELote - O Filtro retornado pelo ponto de entrada LJ7105 gerou seguinte erro : " + TCSQLError())		    	   
			EndIf    
		Endif
    EndIf

    cQuery :=   ChangeQuery(cQuery + cWhere + cOrder)

    dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQuery), _cAlias,.F.,.T.)

    ProcRegua( (_cAlias)->(RecCount()) + 1)

    (_cAlias)->(DbGotop())

    If (_cAlias)->(!EOF() )
        While (_cAlias)->(!EOF())

            aAdd(aTemp, .F.)
            For nX := 1 to len(aCampos)
                aAdd(aTemp, &((_cAlias)->(aCampos[nX])))
            Next nX

            aAdd(aRet, aTemp)
            aTemp := {}

            (_cAlias)->(DbSkip())
        End
    Else
        aAdd(aTemp, .f.)
        For nX := 1 to len(aCampos)
            aAdd(aTemp, CriaVar(aCampos[nX]))
        Next nX
        aAdd(aRet,aTemp)
    Endif
    (_cAlias)->(DbCloseArea())

Return(aRet)

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³NFCEEnv   ºAutor  ³TOTVS IP SOROCABA         º Data ³  10/03/16   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³                                                            º±±
±±º          ³                                                            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ AP                                                        º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function PosItem(cTxtPesquisa,cCombo,oObj)

Local nPos      := 0
Local nPosIndex := 0

    If Alltrim(UPPER(cCombo)) == "ORÇAMENTO"
        nPos :=  aScan(oObj:aArray, { | x | Alltrim(x[2]) == Alltrim(cTxtPesquisa) } )
        If nPos > 0
            oObj:nat := nPos
            oObj:setFocus(nPos)
            oObj:Refresh()
        EndIf
    ElseIf Alltrim(UPPER(cCombo)) == "CLIENTE"
        nPos :=  aScan(oObj:aArray, { | x | Alltrim(x[3]) == Alltrim(cTxtPesquisa) } )
        If nPos > 0
            oObj:nat := nPos
            oObj:setFocus(nPos)
            oObj:Refresh()
        EndIf
    EndIf

Return(.t.)

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³AjusTela  ºAutor  ³TOTVS IP SOROCABA   º Data ³  10/03/16   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Ajusta Tela de selecao dos itens de orcamentos para finali- º±±
±±º          ³zação de orcamentos em LOTE via NFCE.                       º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ AP                                                         º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function AjusTela(nTam)

Local nHRes :=  oMainWnd:nClientWidth   // Resolucao horizontal do monitor

    If nHRes == 640 // Resolucao 640x480 (soh o Ocean e o Classic aceitam 640)
        nTam *= 0.8
    ElseIf (nHRes == 798).Or.(nHRes == 800) // Resolucao 800x600
        nTam *= 1
    Else    // Resolucao 1024x768 e acima
        nTam *= 1.28
    EndIf

    //ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿                                               
    //³Tratamento para tema "Flat"³                                               
    //ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ                                               
    If "MP8" $ oApp:cVersion
        If (Alltrim(GetTheme()) == "FLAT") .Or. SetMdiChild()
            nTam *= 0.90
        EndIf
    EndIf
Return Int(nTam)

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7SetKit ºAutor  ³Varejo              º Data ³  11/11/16   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Função para preencher o array com os itens que pertencem    º±±
±±º          ³a algum kit.                                                º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7SetKit(nLinha, cCodItem, nProd, nCodKit, cItOri)

Default cItOri := ""

AAdd(aProdKit, {nLinha, cCodItem, nProd, nCodKit,cItOri})

Return Nil 

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7IsKit  ºAutor  ³Varejo              º Data ³  11/11/16   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Função para validar se o produto pertence a um kit.         º±±
±±º          ³                                                            º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7IsKit(cCodItem, cCodProd, cCodKit, cItOri)

Local lRet     := .F.    // Retorno da Função
Local cPesq    := ""     // Variavel de pesquisa para o Ascan
Local nKit     := 0      // Posição do produto no array referente ao kit
Local nPosProd := aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_PRODUTO"})][2]      // Posicao da codigo do produto
Local nPosItem := aPosCpo[Ascan(aPosCpo,{|x| Alltrim(Upper(x[1])) == "LR_ITEM"})][2]         // Posicao do Codigo do item
Local nPosKit  := Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_KIT"})                      // Posição do campo que indica se o item pertence a um kit
Local nX       := 0
Local nBkpN    := 0

Default cCodKit := ""
Default cItOri  := ""

If Len(aProdKit) > 0
	cPesq := AllTrim(cCodItem) + AllTrim(cCodProd)
	nKit  := Ascan(aProdKit, {|x| x[2]+x[3] == cPesq})
	If nKit > 0
		cCodKit := aProdKit[nKit][4]
		cItOri  := aProdKit[nKit][5]
		lRet    := .T.
	EndIf
ElseIf nPosKit > 0 .And. !Empty(AllTrim(aCols[n][nPosKit]))
	nBkpN   := n
	cCodKit := AllTrim(aCols[n][nPosKit])
	cItOri  := AllTrim(aCols[n][nPosItem]) 
	For nX := 1 To Len(aCols) 
		If AllTrim(aCols[nX][nPosKit]) == cCodKit
			Lj7SetKit(nX, aCols[nX][nPosItem], AllTrim(aCols[nX][nPosProd]), cCodKit, cItOri)
		EndIf 
	Next
	n    := nBkpN
	lRet := .T.
EndIf

Return lRet

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7PrepDelºAutor  ³ Varejo             º Data ³  14/11/16   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Valida se será excluído somente o produto ou caso seja um  º±±
±±º          ³ kit irá deletar todos os produtos referente ao kit.        º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7PrepDel(lCancECF, lContrPassou, lCancAuto, lEndVendCC, lDelMarg)

Local lRet     := .T.
Local cCodKit  := ""
Local cItOri   := ""
Local lDeleted := aCols[n][Len(aCols[n])]                                                 // Coluna que controla se o item já está deletado
Local nPosItem := aPosCpo[Ascan(aPosCpo,{|x| Alltrim(Upper(x[1])) == "LR_ITEM"})][2]      // Posicao do Codigo do item
Local nPosProd := aPosCpo[Ascan(aPosCpo,{|x| Alltrim(Upper(x[1])) == "LR_PRODUTO"})][2]   // Posicao da Codigo do produto
Local nX       := 0

Default lCancECF      := .T.    // Determina se envia o cancelamento para o ECF quando for concomitante
Default lContrPassou  := .T.    // Determina se faz ou nao o controle do lContrVez
Default lCancAuto     := .T.    // Cancelamento automatico do item não checa permissão do usuario
Default lEndVendCC    := .F.    // Finaliza Venda Concomitante
Default lDelMarg      := .F.    // Verifica se esta deletando o item na validação da margem minima

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³A variavel lContrVez foi criada devido a um bug na funcao de    ³
//³delecao que estah sendo chamada 2 vezes.                       ³
//³Quando esta funcao eh chamada por dentro do fonte nao eh       ³
//³necessario fazer o controle do lContrVez.                       ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Static lContrVez  := .F.
Static lStatusBkp := .F.
Static nBkpN      := 0

If Lj7IsKit(aCols[n][nPosItem], aCols[n][nPosProd], @cCodKit, @cItOri)
	If !lContrVez .And. !lDeleted
		nBkpN := n
		If MsgYesNo(STR0414, STR0015) // "Não é possível excluir somente este produto, pois ele pertence a um Kit de Produtos. Deseja excluir todos os produtos deste kit?"  ###'Atenção'
			lP7VlDev := .F.
			For nX := 1 To Len(aProdKit)
				If aProdKit[nX][4] == cCodKit .And. aProdKit[nX][5] == cItOri
					n    := aProdKit[nX][1]
					oGetVa:oBrowse:nAt := n
					lRet := Lj7ValDel(lCancECF, .F., lCancAuto, lEndVendCC, lDelMarg)
					
					If !lRet
						Exit
					EndIf
				EndIf
			Next
			n := nBkpN
			oGetVa:oBrowse:nAt := n
                
			lStatusBkp := aCols[n][Len(aCols[n])]
		Else
			aCols[n][Len(aCols[n])] := !aCols[n][Len(aCols[n])]
			lRet := .F.
			lStatusBkp := .F.
		EndIf
	ElseIf !lContrVez .And. lDeleted
		MsgAlert(STR0415, STR0015) // "Não é possível restaurar um Kit de Produtos. Favor registrar um novo kit."  ###'Atenção'
		lRet := .F.
	EndIf
	
	If nBkpN > 0 .And. lContrVez .And. lRet
		aCols[nBkpN][Len(aCols[nBkpN])] := lStatusBkp
		oGetVA:Refresh()
	Endif
Else
	lRet := Lj7ValDel( lCancECF, lContrPassou, lCancAuto, lEndVendCC, lDelMarg )
EndIf

If lContrPassou
	lContrVez := !lContrVez
EndIf

Return lRet

//--------------------------------------------------------
/*/{Protheus.doc} LjPerDro
Template Drogaria - Verifica se caixa tem permissão para vender remedio controlado

@param	 _aCols, array , Copia do aCols para validação do Template 
@author  Varejo
@version P12
@since   13/10/2015
@return	Nil
@obs     
@sample
/*/
//--------------------------------------------------------
Function LjPerDro(_aCols)
Local lRet		 := .T.
Local nPosProd	 := 0
Local nX		 := 0 
Local bckReadVar := __ReadVar   

DEFAULT _aCols 		:= {}

If Len(_aCols) > 0 .And. HasTemplate("DRO")  	// se for drogaria e tiver itens
	nPosProd := aScan(aHeader, { |x| AllTrim(x[02]) == "LR_PRODUTO" }) 
	For nX := 1 To Len(aCols)  					// procura pelos itens controlados para pedir permissao do farmaceutico
		If T_DroVerCont(aCols[nX,nPosProd]) 	// se for remedio controlado
			lRet := T_DroVERPerm() 			// verifica permissao do primeiro item controlado
			Exit
		EndIf
	Next
	__ReadVar := bckReadVar		 
EndIf

Return lRet

//-------------------------------------------------------------------
/*/{Protheus.doc} LJ7DadosVL
@description Grava dados VidaLink PBM
@author bruno.inoue
@since 17/04/2017
@version 11.80
/*/
//-------------------------------------------------------------------
Function LJ7DadosVL(aVidaLink)
Default aVidaLink := {}

If Len (aVidaLink) > 2 
	aVidaLinkD := aVidaLink[1]
	aVidaLinkc := aVidaLink[2] 
	nVidaLink  := aVidalink[3]
Else
	aVidaLinkD := {}
	aVidaLinkc := {} 
	If Len(aVidaLink) == 1
		nVidaLink  := aVidaLink[1]
	Else
		nVidaLink  := 2
	EndIf	
EndIf	
Return Nil

//-------------------------------------------------------------------
/*/{Protheus.doc} LJGDadosVL
@description Retorna dados VidaLink PBM salvo
@author bruno.inoue
@since 17/04/2017
@version 11.80
/*/
//-------------------------------------------------------------------
Function LJGDadosVL()
Local aVidalink := {}
aVidalink := {aVidaLinkD,aVidaLinkC,nVidalink}
Return aVidalink

//----------------------------------------------------------
/*/{Protheus.doc} LjVldPbm
Valida se utilizou PBM Funcional Card  

@type 	 function
@author  bruno.inoue
@version P11.8
@since   27/04/2017
@return  lRet
/*/
//----------------------------------------------------------
Function LjVldPbm()
Local aRetPbm 	:= {}
Local lRet		:= .F.

If ExistTemplate("DROVLGet")
	If ExistFunc("LJGDadosVL")
		aRetPbm := LJGDadosVL()
		If Len(aRetPbm) > 0 .And. aRetPbm[3] == 2
			lRet := .T.
		EndIf	
	EndIf	
EndIf	

Return lRet

/*/{Protheus.doc} LjV65Frete
Valida se o cliente possui todos os campos necessarios para a tag <enderDest>
@type		function
@author  	michael.gabriel
@param   	cCliente
@param   	cLoja
@version 	P11.80
@since   	05/06/2017
@return  	lRet
@obs		Somente usado para NFC-e em uma venda Entrega em Domicilio
/*/
Static Function LjV65Frete( cCliente, cLoja )

Local lRet 			:= .T.
Local cMsg 			:= ""

Default cCliente := ""
Default cLoja	 := ""

If ExistFunc("LjBldVlRodape")	//Presente no LOJNFCE.PRW
	cMsg := LjBldVlRodape( 0/*NFC-e*/, .T./*lFrete*/, cCliente, cLoja )
EndIf

If !Empty( cMsg )
	lRet := .F.
	Aviso( STR0429, cMsg, {STR0430}, 3 )	//#"NFC-e Entrega em Domícilio" #"Ok, Entendi"
EndIf

Return lRet

/*/{Protheus.doc} Lj701StInD()
Rotina para Setup de processamento de mensagem única              
@author  fabiana.silva
@version P12.17
@since   14/11/2017
@return  lIntDefPro  Indicativo de processamento de mensagem única                                                                    
/*/
//--------------------------------------------------------
Function Lj701StInD( lProc)

lIntDefPro :=  lProc

Return lIntDefPro

//--------------------------------------------------------

/*/{Protheus.doc} Lj701GtInD()
Rotina para Get de processamento de mensagem única              
@author  fabiana.silva
@version P12.17
@since   14/11/2017
@return  lIntDefPro  Indicativo de processamento de mensagem única                                                                    
/*/
//--------------------------------------------------------
Function Lj701GtInD( )

Return lIntDefPro


/*/{Protheus.doc} LjGetItens()
Rotina para Get de itens recebidos na ExecAuto Loja701   
@author  Paulo Henrique Santos de Moura
@version P12.17
@since   26/12/2017
@return  _aItAuto static contendo dados dos itens recebidos                                                                    
/*/
//--------------------------------------------------------
Function LjGetItens( )
Return _aItAuto

/*/{Protheus.doc} LjGetKeyPs()
Rotina para Get da variavel cTecla
@author  Lucas Novais (lnovais)
@version P12.1.17
@since   08/08/2018
@return                                                                     
/*/
//--------------------------------------------------------
Function LjGetKeyPs()
Return cTecla


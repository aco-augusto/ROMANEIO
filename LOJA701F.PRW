#INCLUDE "PROTHEUS.CH"
#INCLUDE "LOJA701.CH"
#INCLUDE "AUTODEF.CH"
#INCLUDE "TBICONN.CH"

Static lTEFSave	:= SuperGetMV("MV_TEFSAVE",,2) == 1 .AND. nModulo == 12 //Funcionalidade disponível somente no SIGALOJA: Sistema deve guardar e recuperar os dados da transação TEF realizada na venda caso ocorra algum problema antes de concluir a venda? (1=Sim;2=Não)  

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Fun‡„o    ³LOJA701F    	  ³ Autor ³Vendas CRM            ³ Data ³18.12.2011³  ±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descri‡„o ³Fonte para inclusão de funções especificas do Venda Direta       ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
*/

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Fun‡„o    ³FTVDAltPrc    ³ Autor ³Vendas CRM            ³ Data ³18.12.2011³  ±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descri‡„o ³Venda Programada(Venda Direta)                                   ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³cL1Num - Num Orcamento                                         ³±±
±±³          ³aPrc   - aSL4 - Parcelas                                       ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Retorno   ³lRet - .T. - sucesso                                           ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
*/
Function LjVDAltPrc(cL1Num,aPrc)
Local _aCab			:=	{}												//Array do Cabeçalho do Orçamento
Local _aItem			:=	{}												//Array dos Itens do Orçamento
Local aDadosItem    	:=  {}                                             	//Dados do Item montado no loop
Local aCamposSL1    	:=  {}                                            	//Campos de SL1 para montar array pro execauto
Local aCamposSL2    	:=  {}	                                            //Campos de SL1 para montar array pro execauto
Local nI
Local cFilRes			:= ""												// Filial reserva(abastecedora)
Local nDiasRes			:= 0												// Dias de reserva
Local lRet				:= .F.

Default cL1Num			:= ""
Default aPrc			:= {}

Private lMsHelpAuto 	:= .T.												// Variavel de controle interno do ExecAuto
Private lMsErroAuto 	:= .F.												// Variavel que informa a ocorrência de erros no ExecAuto
Private INCLUI 		:= .T.												// Variavel necessária para o ExecAuto identificar que se trata de uma inclusão
Private ALTERA 		:= .F.												// Variavel necessária para o ExecAuto identificar que se trata de uma inclusão

DbSelectArea("SX3")
DbSetOrder(1)
DbSeek("SL1")
While !Eof() .AND. SX3->X3_ARQUIVO == "SL1"
	If X3Uso(SX3->X3_USADO) .AND. cNivel >= SX3->X3_NIVEL 
		If SX3->X3_CONTEXT != "V"
			Aadd(aCamposSL1,Alltrim(SX3->X3_CAMPO))
		EndIf
	EndIf
	SX3->(DbSkip())
End

aCamposSL2 :=   {"L2_NUM"	 ,"L2_PRODUTO",	"L2_QUANT"	,"L2_UM",;
				 "L2_DESC"	 ,"L2_VALDESC",	"L2_DOC"	,"L2_SERIE",;
				 "L2_PDV"	 ,"L2_TABELA",	"L2_DESCPRO","L2_FILIAL",; 
				 "L2_VRUNIT" , "L2_VEND"}

//Monta cabeçalho do orçamento (SLQ)
DbSelectArea("SL1")
DbSetOrder(1)                                                                                                                                                       
If !MsSeek(XFilial("SL1")+cL1Num)                                                                                                                                    
	Aviso( STR0019, STR0248+cL1Num, {STR0028} ) // "Atenção" ### "Numero de Orcamento nao encontrado" ### "Ok"				
Else
	For nI := 1 To Len(aCamposSL1)
		Aadd(_aCab,{"LQ_"+Substr(aCamposSL1[nI],4) , &("SL1->"+aCamposSL1[nI]) , NIL} )
	Next nI	
	//Monta item do orçamento (SLR)
	DbSelectArea("SL2")
	DbSetOrder(1)                                                                                                                                                       
	If !MsSeek(XFilial("SL2")+cL1Num)                                                                                                                                    
		Aviso( STR0019, STR0248+" SL2 "+cL1Num, {STR0028} ) // "Atenção" ### "Numero de Orcamento nao Encontrado" ### "Ok"		
	Else	
		While !Eof() .AND. SL2->L2_NUM == cL1Num
			aDadosItem    :=  {}
			For nI := 1 To Len(aCamposSL2)
				Aadd(aDadosItem,{"LR_"+Substr(aCamposSL2[nI],4) , &("SL2->"+aCamposSL2[nI]) , NIL} )		
			Next nI 
			Aadd(aDadosItem,{"LR_ENTREGA" , "2" , NIL} )	// Seta para nao validar reserva pois apenas sera gravada a parcela.
			Aadd(_aItem,aDadosItem)
			DbSkip()
		End	                
		
		SetFunName("FATA701")
		MSExecAuto({|a,b,c,d,e,f,g,h| FATA701(a,b,c,d,e,f,g,h)},.F.,6,"","",{},_aCab,_aItem	,aPrc)
		
		If lMsErroAuto
			lRet := .F.
			MostraErro()        
			DisarmTransaction()
			// Libera sequencial
			RollBackSx8()	
		Else
			lRet := .T.
		EndIf                                    
	EndIf
EndIf
	
Return lRet

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Fun‡„o    ³FTVDVProg     ³ Autor ³Vendas CRM            ³ Data ³18.12.2011³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descri‡„o ³Venda Programada                                               ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³cL2Num - Num Orcamento                                         ³±±
±±³          ³cL2Item - Item de SL2                                          ³±±
±±³          ³cL2Prod - Codigo Produto Padrao SL2                            ³±±
±±³          ³cB2Prod - Codigo Produto Final SB2                             ³±±
±±³          ³cB2Local - Local de SB2 do produto final                       ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Retorno   ³Nenhum                                                         ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
*/
Function LjVDVProg(cL2Num,cL2Item,cL2Prod,cB2Prod,cB2Local)  

Local aArea     	:= GetArea()                                                     
Local aAreaSL1              //Area SL1 do registro cL2Num
Local aAreaSL2              //Area SL2 do registro cL2Num
Local cLocalGen             //Armazem do Produto Genérico                        
Local cL1NumRes    
Local cPedRes
Local lRet 		:= .T.  


Default cL2Num	 	:= ""
Default cL2Item	:= ""
Default cL2Prod  	:= "" 
Default cB2Prod  	:= "" 
Default cB2Local 	:= ""

DbSelectArea("SL1")
DbSetOrder(1)    
                                                                                                                                                   
If !MsSeek(XFilial("SL1")+cL2Num)                                                                                                                                    
	Aviso( STR0019, STR0248+cL2Num, {STR0028} ) // "Atenção" ### "Numero de Orçamento não encontrado " ### "Ok"
	Conout( STR0019, STR0248+cL2Num, {STR0028} )
	lRet := .F.
EndIf

If lRet .AND. (Empty(SL1->L1_ORCRES) .OR. Empty(SL1->L1_PEDRES))
	Aviso( STR0019, STR0249, {STR0028} ) // "Atenção" ### "O Orçamento informado deverá ser o orçamento criado na finalização da venda. O Orçamento que possui pedido de venda." ### "Ok"
	Conout( STR0019, STR0249, {STR0028} )
	lRet := .F.
EndIf                      

cL1NumRes := SL1->L1_ORCRES        
cPedRes   := SL1->L1_PEDRES     
aAreaSL1 := GetArea()

DbSelectArea("SL1")
DbSetOrder(1)                                                                                                                                                       
If lRet .AND. !MsSeek(XFilial("SL1")+cL1NumRes)                                                                                                                                    
	Aviso( STR0019, STR0248+cL1NumRes, {STR0028} ) // "Atenção" ### "" ### "Ok"
	Conout( STR0019, STR0248+cL1NumRes, {STR0028} )
	lRet := .F.
EndIf

If lRet .AND. (SuperGetMV("MV_VEICULO",,"N") <> "S" .OR. SL1->(FieldPos("L1_ORIGEM")) == 0 .OR. SL1->L1_ORIGEM <> "V")
	Aviso( STR0019, STR0250, {STR0028} ) // "Atenção" ### "Integração de Gestão de Concessionárias Desativada. O Registro SL1 a ser alterado deverá ter sido criado por MsExecAuto do FATA701 através do módulo de gestão de concessionárias." ### "Ok"
	Conout( STR0019, STR0250, {STR0028} )
	lRet := .F.		
EndIf                                                                  

DbSelectArea("SL2")
DbSetOrder(1)                                                                                                                                                       
If lRet .AND. !MsSeek(XFilial("SL2")+cL2Num+cL2Item+cL2Prod)                                                                                                                                    
	Aviso( STR0019, STR0251, {STR0028} ) // "Atenção" ### ""Numero de Orçamento não encontrado em SL2"" ### "Ok"
	Conout( STR0019, STR0251, {STR0028} )
	lRet := .F.
EndIf                     

aAreaSL2 := GetArea()            

DbSelectArea("SL2")
DbSetOrder(1)                                                                                                                                                       
If lRet .AND. !MsSeek(XFilial("SL2")+cL1NumRes+cL2Item+cL2Prod)                                                                                                                                    
	Aviso( STR0019, STR0251, {STR0028} ) // "Atenção" ### ""Numero de Orçamento não encontrado em SL2"" ### "Ok"
	Conout( STR0019, STR0251, {STR0028} )
	lRet := .F.
EndIf                                                    

cLocalGen := SL2->L2_LOCAL //Armazem do Produto Generico

DbSelectArea("SB1")
DbSetOrder(1)
If lRet .AND. !MsSeek(XFilial("SB1")+cB2Prod)
	Aviso( STR0019, STR0252, {STR0028} ) // "Atenção" ### "O Produto Final e o Local Informado não foram encontrados em SB1." ### "Ok"
	Conout( STR0019, STR0252, {STR0028} )
	lRet := .F.
EndIf                                                       

DbSelectArea("SB2")
DbSetOrder(1)
If lRet .AND. !MsSeek(XFilial("SB2")+cB2Prod+cB2Local)
	Aviso( STR0019, STR0253, {STR0028} ) // "Atenção" ### "O Produto Final e o Local Informado não foram encontrados em SB2." ### "Ok"
	Conout( STR0019, STR0253, {STR0028} )
	lRet := .F.
EndIf                                                       
		                                                    
If lRet .AND. SaldoSb2() <= 0 
	Aviso( STR0019, STR0254, {STR0028} ) // "Atenção" ### "O Produto Final e o Local Informado não possuem saldo em estoque." ### "Ok"
	Conout( STR0019, STR0254, {STR0028} )
	lRet := .F.
EndIf		

DbSelectArea("SC5")
DbSetOrder(1)
If lRet .AND. !MsSeek(XFilial("SC5")+cPedRes)
	Aviso( STR0019, STR0255, {STR0028} ) // "Atenção" ### "O Pedido de Venda do Orçamento não foi encontrado." ### "Ok"
	Conout( STR0019, STR0255, {STR0028} )
	lRet := .F.
EndIf

DbSelectArea("SC6")
DbSetOrder(1)
If lRet .AND. (!MsSeek(XFilial("SC6")+cPedRes+cL2Item+cL2Prod) .OR. SC6->C6_LOCAL <> SL2->L2_LOCAL)
	Aviso( STR0019, STR0256, {STR0028} ) // "Atenção" ### "Item do Orçamento Informado para Venda Progresso não encontrado." ### "Ok"
	Conout( STR0019, STR0256, {STR0028} )
	lRet := .F.
EndIf                                                                     

DbSelectArea("SC9")
DbSetOrder(2)
If lRet .AND. (!MsSeek(XFilial("SC9")+SL1->L1_CLIENTE+SL1->L1_LOJA+cPedRes+cL2Item) .OR. SC9->C9_PRODUTO <> cL2Prod .OR. SC9->C9_LOCAL <> SL2->L2_LOCAL)
	Aviso( STR0019, STR0256, {STR0028} ) // "Atenção" ### "Item do Orçamento Informado para Venda Progresso não encontrado." ### "Ok"
	Conout( STR0019, STR0256, {STR0028} )
	lRet := .F.
EndIf                                                                     

If lRet                              
	BeginTran()                                                             
		RecLock("SL2",.F.)
		REPLACE SL2->L2_PRODUTO WITH cB2Prod
		REPLACE SL2->L2_DESCRI  WITH SB1->B1_DESC	
		REPLACE SL2->L2_LOCAL   WITH cB2Local
		MsUnlock("SL2")       
		RestArea(aAreaSL2)
		RecLock("SL2",.F.)
		REPLACE SL2->L2_PRODUTO WITH cB2Prod
		REPLACE SL2->L2_DESCRI  WITH SB1->B1_DESC	
		REPLACE SL2->L2_LOCAL   WITH cB2Local
		MsUnlock("SL2")	                                     
		RecLock("SC6",.F.)
		REPLACE SC6->C6_PRODUTO WITH cB2Prod
		REPLACE SC6->C6_DESCRI  WITH SB1->B1_DESC	
		REPLACE SC6->C6_LOCAL   WITH cB2Local
		MsUnlock("SC6")
		RecLock("SC9",.F.)
		REPLACE SC9->C9_PRODUTO WITH cB2Prod
		REPLACE SC9->C9_LOCAL   WITH cB2Local
		MsUnlock("SC9")	
		RecLock("SB2",.F.)
		REPLACE SB2->B2_QPEDVEN WITH SB2->B2_QPEDVEN+SL2->L2_QUANT
		MsUnlock("SB2")
		DbSelectArea("SB2")  
		DbSetOrder(1)	
		If !MsSeek(XFilial("SB2")+cL2Prod+cLocalGen)
			Aviso( STR0019, STR0257, {STR0028} ) // "Atenção" ### "Armazem original do Produto generico nao encontrado." ### "Ok" 
			DisarmTransaction()
			EndTran()
			lRet := .F.	
		EndIf
		RecLock("SB2",.F.)
		REPLACE SB2->B2_QPEDVEN WITH SB2->B2_QPEDVEN-SL2->L2_QUANT
		MsUnlock("SB2")	
	EndTran()
	MsUnlockAll()
EndIf
	          
RestArea(aArea)

Return lRet  

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±³Funcao    ³FTVDT_SUFR ³ Autor ³ Vendas Clientes      ³ Data ³ 04/07/02³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ³±±
±±³Descricao ³ Pertencente ao grupo das funcoes de Totais, tem como		  ³±±
±±³          ³ objetivo manipular o valor total da venda	 			  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ³±±
±±³Sintaxe   ³ FTVDT_SUFR(nExp1, uExp2)				                 	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ±±
±±³Parametros³ nExp1 - O que se deseja manipular o valor 		 		  	³±±
±±³          ³ uExp1 - Qual valor deve conter (em caso de alteracao)	  	³±±
±±³          ³ 															    ³±±
±±³          ³ Para nExp1, tem-se:										  	³±±
±±³          ³ 1 - Titulo												  	³±±
±±³          ³ 2 - Valor												  	³±±
±±³          ³ 3 - Objeto												  	³±±
±±³          ³ 4 - Picture												  	³±±
±±³          ³ 															  	³±±
±±³          ³ Exemplos:												  	³±±
±±³          ³ Para alterar o titulo do valor total						  	³±±
±±³          ³ FTVDT_Total(1, "Valor total da venda")					  	³±±
±±³          ³ 															  	³±±
±±³          ³ Para receber o titulo do valor total						  	³±±
±±³          ³ FTVDT_SUFR(1)								  			  	³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ³±±
±±³Uso		 ³ FATA701 													  	³±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function LjVDT_SUFR( nTipo, uParam )

If !Lj7T_VlTp(nTipo, "Lj7Total", uParam)
	Return .F.
EndIf

Return Lj7T_Array( 7, nTipo, uParam )

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³FATA701A  ºAutor  ³Vendas CRM           º Data ³  08/16/11  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Inicializa as variaveis fiscais para o correto calculo     º±±
±±º          ³ do Suframa                                                 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ Valor de Suframa											  º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍº±±
±±ºUso       ³ Fata701                                                    º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function LjVDSuframa()
Local aArea			:= GetArea()
Local aAreaSA1      := SA1->(GetArea())
Local aAreaSF4      := SF4->(GetArea())
Local nPosProd		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_PRODUTO"})][2]			// Posicao da codigo do produto
Local nPosQuant		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_QUANT"})][2]				// Posicao da Quantidade
Local nPosVlUnit	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VRUNIT"})][2]				// Posicao do Valor unitario do item
Local nPosVlItem	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VLRITEM"})][2]			// Posicao do Valor do item
Local nPosValDesc	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VALDESC"})][2]			// Posicao do valor de desconto
Local nPosDtTes		:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_TES"})							// Posicao do Codigo do TES  
Local nX        	:= 0                                                                                // Variavel a ser utilizada no FOR
Local nPrcLista 	:= 0                                                                                // Variavel para armazenar o preço de lista
Local nValMerc  	:= 0                                                                                // Variavel para armazenar o valor de mercado do item
Local nDesconto 	:= 0                                                                                // Variavel para armazenar o valor de desconto
Local cProduto  	:= ""                                                                               // Variavel para armazenar o codigo do produto
Local nSuframa  	:= 0                                                                                // Variavel para armazenar e retornar o valor de suframa
Local cTpFrete		:= "" //Tipo do Frete

SA1->(DbSetOrder(1))
If SA1->(MsSeek(xFilial("SA1")+M->LQ_CLIENTE+M->LQ_LOJA))

	MaFisSave()
	MaFisEnd() 
	cTpFrete := Lj7TpFrete(M->LQ_CLIENTE,M->LQ_LOJA)
	cTpFrete	:= IIf( Empty(cTpFrete) .And. (M->LQ_TPFRET == "S" .OR. M->LQ_TPFRET == "0"), "S", cTpFrete)

	MaFisIni(M->LQ_CLIENTE,;	// 1-Codigo Cliente/Fornecedor
		M->LQ_LOJA,;			// 2-Loja do Cliente/Fornecedor
		"C",;					// 3-C:Cliente , F:Fornecedor
		"S",;					// 4-Tipo da NF
		SA1->A1_TIPO,;			// 5-Tipo do Cliente/Fornecedor
		Nil,;					// 06-Relacao de Impostos que suportados no arquivo
		Nil,;					// 07-Tipo de complemento
		Nil,;					// 08-Permite Incluir Impostos no Rodape .T./.F.
		Nil,;					// 09-Alias do Cadastro de Produtos - ("SBI" P/ Front Loja)
		"MATA461",;				// 10-Nome da rotina que esta utilizando a funcao
		Nil,;					// 11-Tipo de documento
		Nil,;					// 12-Especie do documento
		Nil,;					// 13-Codigo e Loja do Prospect 
		Nil,;					// 14-Grupo Cliente
		Nil,;					// 15-Recolhe ISS
		Nil,;					// 16-Codigo do cliente de entrega na nota fiscal de saida
		Nil,;					// 17-Loja do cliente de entrega na nota fiscal de saida
		Nil,;					// 18-Informacoes do transportador [01]-UF,[02]-TPTRANS
		NIL,;					//19
		NIL,;					//20
		NIL,;					//21
		NIL,;					//22	
		NIL,;					//23
		NIL,;					//24
		NIL,;					//25
		cTpFrete)				//26
		
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Agrega os itens para a funcao fiscal         ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If nPosProd > 0 .And. nPosValDesc > 0 .And. nPosVlUnit > 0 .And. nPosQuant > 0 .And. nPosDtTes > 0
		For nX := 1 To Len(aCols)
	
			If !aTail(aColsDet[nX]) .AND. !Empty(aCols[nX][nPosProd])		
				
				cProduto := aCols[nX][nPosProd]
				MatGrdPrRf(@cProduto)
	
	            SF4->(dbSetOrder(1))
	            SF4->(MsSeek(xFilial("SF4")+aColsDet[nX][nPosDtTes]))
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Armazena os valores para inicializar a MATXFIS     ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				nValMerc  := aCols[nX][nPosVlItem]
				nPrcLista := aCols[nX][nPosVlUnit]
				nDesconto := aCols[nX][nPosValDesc]
				
				//Para os outros paises, este tratamento e feito no programas que calculam os impostos.
				If cPaisLoc=="BRA" .or. GetNewPar('MV_DESCSAI','1') == "2"
					nValMerc  += nDesconto
				Endif
									
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Agrega os itens para a funcao fiscal         ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				MaFisAdd(cProduto,;   				// 1-Codigo do Produto ( Obrigatorio )
					aColsDet[nX][nPosDtTes],;	   	// 2-Codigo do TES ( Opcional )
					aCols[nX][nPosQuant],;  		// 3-Quantidade ( Obrigatorio )
					nPrcLista,;		  				// 4-Preco Unitario ( Obrigatorio )
					nDesconto,; 					// 5-Valor do Desconto ( Opcional )
					"",;	   						// 6-Numero da NF Original ( Devolucao/Benef )
					"",;							// 7-Serie da NF Original ( Devolucao/Benef )
					0,;								// 8-RecNo da NF Original no arq SD1/SD2
					0,;								// 9-Valor do Frete do Item ( Opcional )
					0,;								// 10-Valor da Despesa do item ( Opcional )
					0,;								// 11-Valor do Seguro do item ( Opcional )
					0,;								// 12-Valor do Frete Autonomo ( Opcional )
					nValMerc,;						// 13-Valor da Mercadoria ( Obrigatorio )
					0)
			EndIf
	   	Next nX
	   	
	EndIf
		
	nSuframa:= MaFisRet(, "NF_DESCZF")
	
EndIf

RestArea(aAreaSA1)
RestArea(aAreaSF4)
RestArea(aArea)

Return nSuframa	

/*±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±³Fun‡…o    ³FTVDItDedIcm³ Autor ³ Vendas Clientes       ³ Data ³ 13/07/12 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descri‡…o ³ Retorna o valor total da dedução de ICMS dos itens.		    ³±±
±±³			 ³															   	³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³ Uso      ³FTVD701C                                                      ³±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function LjVDItDedIcm()

Local nX := 0
Local nVlrDedIcm := 0

If Type("aCols") == "A" .And. MaFisFound("NF")
	For nX := 1 To Len(aCols)
		If !aCols[nX][Len(aCols[nX])]
			nVlrDedIcm += MaFisRet(nX,"IT_DEDICM")
		EndIf		
	Next nX
Else 
	nVlrDedIcm := 0
EndIf

Return nVlrDedIcm

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³MyFATA701  	  ºAutor  ³Vendas Clientes º Data ³  03/02/2011 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Efetua o teste do ExecAuto do Venda Direta (FATA701).    	º±±
±±º          ³ A chamada desta função deverá ser adicionada ao menu do Vendaº±±	
±±º          ³ Assistida para ser testado.									º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametro ³ Nenhum.                        								º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ FATA701                                                      º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/	
User Function MyVDFT701

Local _aCab			:=	{}												//Array do Cabeçalho do Orçamento
Local _aItem			:=	{}												//Array dos Itens do Orçamento
Local _aParcela		:=	{}												//Array das Parcelas do Orçamento
Local _nPercDesc		:=	0												//Percentual do Desconto
Local cFilRes			:= ""												// Filial reserva(abastecedora)
Local nDiasRes			:= 0												// Dias de reserva

Private lMsHelpAuto 	:= .T.												// Variavel de controle interno do ExecAuto
Private lMsErroAuto	:= .F.												// Variavel que informa a ocorrência de erros no ExecAuto
Private INCLUI 		:= .T.												// Variavel necessária para o ExecAuto identificar que se trata de uma inclusão
Private ALTERA 		:= .F.												// Variavel necessária para o ExecAuto identificar que se trata de uma inclusão

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//| Abertura do ambiente                                         |
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
ConOut(Repl("-",80))
ConOut(PadC("Teste Prepare Env",80))
PREPARE ENVIRONMENT EMPRESA 'T1' FILIAL 'D MG 01' USER "caixa" PASSWORD '1' TABLES "SX6" MODULO "FAT"
Conout(cEmpAnt+"-"+cFilAnt)

//Monta cabeçalho do orçamento (SLQ)
_aCab:= {    	{"LQ_VEND"		,"000001"         ,NIL},;
                {"LQ_COMIS"             ,0        ,NIL},;    
                {"LQ_CLIENTE"		,"1     "     ,NIL},;
                {"LQ_LOJA"		,"01"             ,NIL},;
                {"LQ_TIPOCLI"		,"F"          ,NIL},;
                {"LQ_VLRTOT"		, 416          ,NIL},;
                {"LQ_DESCONT"		, 0           ,NIL},;
                {"LQ_VLRLIQ"		, 416          ,NIL},;
                {"LQ_NROPCLI"		,"         "  ,NIL},;
                {"LQ_DTLIM"		,dDatabase ,NIL},;
                {"LQ_DOC"		,"000000214   "      ,NIL},;
                {"LQ_SERIE"		,"PRE "            ,NIL},;
                {"LQ_PDV"		,"0001      "     ,NIL},;
                {"LQ_EMISNF"		,dDatabase   ,NIL},;
                {"LQ_VALBRUT"		, 516          ,NIL},;
                {"LQ_VALMERC"		, 516          ,NIL},;
                {"LQ_TIPO"		    ,"V"          ,NIL},;
                {"LQ_DESCNF"		, 0           ,NIL},;
                {"LQ_OPERADO"		,"C02"        ,NIL},;
                {"LQ_DINHEIR"		, 516          ,NIL},;
                {"LQ_ENTRADA"		, 516          ,NIL},;
                {"LQ_PARCELA"		, 1           ,NIL},;
                {"LQ_CONDPG"		,"001"        ,NIL},;
                {"LQ_FORMPG"		,"R$"         ,NIL},;
                {"LQ_EMISSAO"		,dDatabase   ,NIL},;
                {"LQ_NUMCFIS"		,"003025   "  ,NIL},;
                {"LQ_IMPRIME"		,"1S        " ,NIL},;
                {"LQ_VLRDEBI"		, 0           ,NIL},;
                {"LQ_HORA"		,""               ,NIL},;
                {"LQ_NUMMOV"		,"1 "         ,NIL},;         
                {"AUTRESERVA"       ,"000001"     ,NIL}}
                

aAdd(_aItem,{	{"LR_PRODUTO",   "1             ",NIL},;
				{"LR_QUANT"  ,    1               ,NIL},;
				{"LR_UM"     ,   "UN"             ,NIL},;
				{"LR_DESC"   ,    0               ,NIL},;
				{"LR_VALDESC",    0               ,NIL},;
				{"LR_DOC"    ,   "000000214   "      ,NIL},;
				{"LR_SERIE"  ,   "PRE "            ,NIL},;
				{"LR_PDV"    ,   "0001      "     ,NIL},;
				{"LR_TABELA" ,   "1"              ,NIL},;
				{"LR_DESCPRO",    0               ,NIL},;
				{"LR_FILIAL" ,   "D MG 01"             ,NIL},;
				{"LR_VRUNIT" ,   516              ,NIL},;
				{"LR_ENTREGA",   "3"              ,NIL},;				
				{"LR_VEND"   ,   "000001"         ,NIL} })


//Monta o cabeçalho do orçamento (aPagtos)
aAdd(_aParcela,{{"L4_DATA"		,dDatabase		         ,NIL},;
				{"L4_VALOR"		,516	                 ,NIL},;
				{"L4_FORMA"		, "R$             "		 ,NIL},;
				{"L4_ADMINIS"	, "                    " ,NIL},;
				{"L4_FORMAID"   , " "			         ,NIL},;
				{"L4_MOEDA"		,  0					 ,NIL}}) 

SetFunName("FATA701")
MSExecAuto({|a,b,c,d,e,f,g,h| FATA701(a,b,c,d,e,f,g,h)},.F.,3,"","",{},_aCab,_aItem	,_aParcela)

If lMsErroAuto
	Alert("Erro no ExecAuto")
	MostraErro()        
	DisarmTransaction()
	// Libera sequencial
	RollBackSx8()
	
Else
	Alert("Sucesso na execução do ExecAuto")
EndIf

Return 
                  
User Function LjVDVProg()
	Local cL2Num   := "000103"                          
	Local cL2Item  
	Local cL2Prod  
	Local cB2Prod  
	Local cB2Local 
	Local lRet
	ConOut(PadC("Prepare Environment",80))
	PREPARE ENVIRONMENT EMPRESA 'T1' FILIAL 'D MG 01' USER "caixa" PASSWORD '1' TABLES "SX6" MODULO "FAT"
	Conout(cEmpAnt+"-"+cFilAnt)		
	
	cL2Item  := Pad("01",TamSX3("L2_ITEM")[1])
	cL2Prod  := Pad("1",TamSX3("L2_PRODUTO")[1])
	cB2Prod  := Pad("2",TamSX3("L2_PRODUTO")[1])	
	cB2Local := Pad("01",TamSX3("L2_LOCAL")[1])	
	lRet := LjVDVProg(cL2Num,cL2Item,cL2Prod,cB2Prod,cB2Local)
	
	If lRet
		Conout("Venda Progresso OK")			
	Else
		Conout("Erro na Venda Progresso")		
	EndIf  
Return

User Function LjVDAltPrc()                                    
	Local aPrc    := {}                                                  
	Local cNumSL1 := "000099"
	
//Monta o cabeçalho do orçamento (aPagtos)
aAdd(aPrc,{{"L4_NUM"		,cNumSL1		         ,NIL},;
				{"L4_DATA"		,Date()		         ,NIL},;
				{"L4_VALOR"		,3                        ,NIL},;
				{"L4_FORMA"		, "CH             "		 ,NIL},;
				{"L4_ADMINIS"	, "                    " ,NIL},;
				{"L4_FORMAID"   , " "			         ,NIL},;
				{"L4_MOEDA"		,  0					 ,NIL}})
aAdd(aPrc,{{"L4_NUM"		,cNumSL1		         ,NIL},;
				{"L4_DATA"		,Date()+30	         ,NIL},;
				{"L4_VALOR"		,4                        ,NIL},;
				{"L4_FORMA"		, "R$             "		 ,NIL},;
				{"L4_ADMINIS"	, "                    " ,NIL},;
				{"L4_FORMAID"   , " "			         ,NIL},;
				{"L4_MOEDA"		,  0					 ,NIL}})

	ConOut(PadC("Prepare Environment",80))
	PREPARE ENVIRONMENT EMPRESA 'T1' FILIAL 'D MG 01' USER "caixa" PASSWORD '1' TABLES "SX6" MODULO "FAT"
	Conout(cEmpAnt+"-"+cFilAnt)
					
	LjVDAltPrc(cNumSL1,aPrc)
Return
          
/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³LjGuardaTef  	  ºAutor  ³Leandro Lima  º Data ³  09/11/2015   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Funcao responsavel por armazenar os dados da venda TEF   	º±±
±±º          ³ Todos os principais campos do objeto oTEF sao armazendados   º±±	
±±º          ³ justamente para que possa ser recuperado posteriormente      º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/	
Function LjGuardaTef(cNumeOrc,aTefBKP)
Local lRet 			:= .F.
Local cFile			:= ""
Local cTefDIR		:= "\AUTOCOM\TEF"+cEmpAnt+StrTran(Alltrim(cFilAnt)," ","")
Local nHandle		:= 0
Local cTexto		:= ""
Local nX			:= 0
Local lLoopTef		:= .F.
Local nBkpnX		:= 0
Local nPend			:= 0

DEFAULT cNumeOrc := ""
DEFAULT aTefBKP	 := {}


If lTEFSave

	cFile  := cTefDIR+"\" + cNumeOrc +".CSV"
	//TO DO : talvez melhor apagar o arquivo para ele criar novamente
	If !File( cFile )  .AND. Type("oTef") <> "U" .AND. Len(oTEF:aRETCARTAO) > 0 .AND.;
		 (oTef:lTefOk .OR. (!oTef:lTefOk .AND. Len(aTefBKP) > 0 ))
		 
		 LjGrvLog(cNumeOrc,"Efetuou a guarda do TEF")
		 	 
		cTexto := "oTef:nCodFuncao"+";"+AllTrim(STR(oTef:nCodFuncao)) +";" 
		cTexto += "oTef:cCupom"+";"+oTef:cCupom +";"
		cTexto += "oTef:cData"+";"+oTef:cData +";"
		cTexto += "oTef:cHora"+";"+oTef:cHora +";"
		cTexto += "oTef:cOperador"+";"+oTef:cOperador+";"
	
		// Caso a transacao total nao esteja OK porem 1 cartão passou
		lLoopTef := (!oTef:lTefOk .AND. Len(aTefBKP) > 0 )
		
		For nX := 1 to Len(oTef:aRetCartao)
			If lLoopTef
				For nPend := 1 to Len(aTefBKP)
					If oTef:aRetCartao[nx]:DENTRADA		== aTefBKP[nPend]:DENTRADA	  	.AND.;
						oTef:aRetCartao[nX]:NVLRTRANS 	== aTefBKP[nPend]:NVLRTRANS	  	.AND.;
						oTef:aRetCartao[nX]:CFORMA 		== aTefBKP[nPend]:CFORMA	  	.AND.;
						oTef:aRetCartao[nX]:CIDCART 	== aTefBKP[nPend]:CIDCART	  	.AND.;
						oTef:aRetCartao[nX]:NVLRENTRADA	== aTefBKP[nPend]:NVLRENTRADA 	 
						Exit
					EndIf	
				Next nPend
				nBkpnX 	:= nX
				nX		:= nPend 
			EndIf	
			cTexto += "oTef:aRetCartao["+AllTrim(Str(nX))+"]:nParcelas"+";"+AllTrim(STR(oTef:aRetCartao[nX]:nParcelas))+";"
			cTexto += "oTef:aRetCartao["+AllTrim(Str(nX))+"]:cIdCart" +";"+oTef:aRetCartao[nX]:cIdCart+";"
			cTexto += "oTef:aRetCartao["+AllTrim(Str(nX))+"]:cTipCart"+";"+oTef:aRetCartao[nX]:cTipCart+";"
			cTexto += "oTef:aRetCartao["+AllTrim(Str(nX))+"]:cDescAdm"+";"+oTef:aRetCartao[nX]:cDescAdm+";"
			cTexto += "oTef:aRetCartao["+AllTrim(Str(nX))+"]:dEntrada"+";"+DTOS(oTef:aRetCartao[nX]:dEntrada)+";"
			cTexto += "oTef:aRetCartao["+AllTrim(Str(nX))+"]:nVlrTrans"+";"+AllTrim(STR(oTef:aRetCartao[nX]:nVlrTrans))+";"
			cTexto += "oTef:aRetCartao["+AllTrim(Str(nX))+"]:nVlrEntrada"+";"+AllTrim(STR(oTef:aRetCartao[nX]:nVlrEntrada))+";"
			cTexto += "oTef:aRetCartao["+AllTrim(Str(nX))+"]:cAutoriza"+";"+oTef:aRetCartao[nX]:cAutoriza+";"
			cTexto += "oTef:aRetCartao["+AllTrim(Str(nX))+"]:cNsuAutor"+";"+oTef:aRetCartao[nX]:cNsuAutor+";"
			cTexto += "oTef:aRetCartao["+AllTrim(Str(nX))+"]:cPosCart"+";"+oTef:aRetCartao[nX]:cPosCart+";"
			cTexto += "oTef:aRetCartao["+AllTrim(Str(nX))+"]:cForma"+";"+oTef:aRetCartao[nX]:cForma+";"
			cTexto += "oTef:aRetCartao["+AllTrim(Str(nX))+"]:cNsuSitef"+";"+oTef:aRetCartao[nX]:cNsuSitef+";"
			cTexto += "oTef:aRetCartao["+AllTrim(Str(nX))+"]:cCupom01"+";"+oTef:aRetCartao[nX]:cCupom01+";"
			cTexto += "oTef:aRetCartao["+AllTrim(Str(nX))+"]:cCupom02"+";"+oTef:aRetCartao[nX]:cCupom02+";"
			cTexto += "oTef:aRetCartao["+AllTrim(Str(nX))+"]:cCodRede"+";"+oTef:aRetCartao[nX]:cCodRede+";"
			cTexto += "oTef:aRetCartao["+AllTrim(Str(nX))+"]:cDescRede"+";"+oTef:aRetCartao[nX]:cDescRede+";"

			
			
			If lLoopTef
				nX	:= nBkpnX 
			EndIf
		Next nX
		
		cTexto := Left(cTexto, Len(cTexto)-1)
			
		If !File( cFile ) // Caso nao exista cria o arquivo
			MakeDir( "\AUTOCOM" )
			MakeDir( cTefDIR )
			nHandle := FCreate( cFile )
			FClose( nHandle )
		EndIf
		If File( cFile )
			nHandle := FOpen( cFile, 2 )
			FSeek ( nHandle, 0, 2 )			// Posiciona no final do arquivo.
			FWrite( nHandle, cTexto )
			FClose( nHandle )
		EndIf
	EndIf
			
EndIf

Return lRet

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³LjRecupTef  	  ºAutor  ³Leandro Lima  º Data ³  09/11/2015   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Funcao responsavel por armazenar os dados da venda TEF   	º±±
±±º          ³ Todos os principais campos do objeto oTEF sao armazendados   º±±	
±±º          ³ justamente para que possa ser recuperado posteriormente      º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/	
Function LjRecupTef(cNumeOrc,lTemTefPend,aTefBKP)

Local cTefDIR		:= "\AUTOCOM\TEF"+cEmpAnt+StrTran(Alltrim(cFilAnt)," ","")
Local cLinha		:= ""		//variavel de leitura da linha
Local nHdlFile		:= 0	
Local aLinha		:= {}		//Array contendo todos os Registros ja desmembrados
Local lRet			:= .F.
Local nSeq			:= 0
Local nLast			:=0
Local cTipVar		:= ""
Local nAt			:= 0
Local nX			:= 0
Local cTef			:= ""
Local cStrTokArr2	:= "StrTokArr2"
Local lFuncOk		:= .F.

DEFAULT cNumeOrc	:= ""
DEFAULT lTemTefPend := .F.
DEFAULT aTefBKP		:= {}

/*	Protegemos a execução da função StrTokArr2, pois como o robopatch utiliza a primeira versão da build para gerar os pacotes,
	esses pacotes podem não possuir essa função, causando o erro "Invalid Type Function" em tempo de execução.
*/

lFuncOk := ExistFunc(cStrTokArr2)

If lTEFSave
	
	cFile  := cTefDIR+"\" + cNumeOrc +".CSV"
	If File(cFile) .AND. !lFuncOk
		MsgStop(STR0426 + CRLF + STR0427, STR0428)	//"Não foi possível recuperar o arquivo de Transações TEF." #"Função StrTokArr2 não compilada no RPO. Por favor, atualize a build 7.00.131227A com data de geração superior a 08/09/2014."#"Erro"	
	EndIf
	nHdlFile := FT_FUse(cFile)
	
	fClose(nHdlFile)
	nHdlFile := FT_FUse(cFile)
	If nHdlFile <> -1 .AND. lFuncOk
		FT_FGoTop()					// Posiciona na primeria linha
		
		While !FT_FEOF()   			// Percorre todo o arquivo
			cLinha := FT_FReadLn() 	// Retorna a linha corrent
			If AT(";",cLinha) == 0
				cLinha := cLinha+ Chr(10)
			EndIf
			cTef += cLinha
			FT_FSKIP()	// Pula para proxima linha  
		End
		FT_FUSE() // Fecha o Arquivo
		fClose(nHdlFile)

		//Se estiver processando um arquivo antes da alteração, pode dar problemas
		If Right(cTef,1) == ";"
			cTef := Left(cTef, Len(cTef)-1)
		EndIf
	
		aLinha	:=  &cStrTokArr2.(cTef, ";",.T.)
	
		If Type("oTef") <> "U"
			For nX := 1 to Len(aLinha) step 2
				nAt :=  AT("]",aLinha[nX]) + 2
				// Se no arquivo tiver varios cartoes, tem que adicionar no aRetCartao
				If nAt > 2 .AND. Len(oTef:aRetCartao) < Val(SubStr(aLinha[nX],nAt-3,1))
					Aadd(oTef:aRetCartao,{})
					oTef:aRetCartao[Len(oTef:aRetCartao)] := MSRetCartao():New()
				ElseIf nAt == 2  // Caso nao seja aRetCartao 
					nAt :=  AT(":",aLinha[nX]) +1
				EndIf
				cTipVar := SubStr(aLinha[nX],nAt,1)
				
				If UPPER(cTipVar) == "N"
					&(aLinha[nX]) := Val(aLinha[nX+1])
				ElseIf UPPER(cTipVar) == "D"
					&(aLinha[nX]) := STOD(aLinha[nX+1])
				Else 
					&(aLinha[nX]) := aLinha[nX+1]
				EndIf
			Next nX
			If Len(aLinha)  > 0
				LjGrvLog(cNumeOrc,"Efetuou a recuperacao do TEF")
				oTef:lTefOk := .T. 
				aTefBKP := aClone(oTef:aRetCartao)
				lTemTEFPend := .T.
			EndIf	
		EndIf
	ElseIf nHdlFile <> -1
		fClose(nHdlFile)
	EndIf	

EndIf

Return lRet


/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³ LjEraseTef  	  ºAutor  ³                º Data ³  25/02/2016 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Funcao responsavel por apagar o arquivo .csv que contem os   º±±
±±º          ³ dados da venda TEF. O Arquivo eh apagado na situacao onde a  º±±	
±±º          ³ transacao TEF eh cancelada.                                  º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function LjEraseTef(cNumeOrc)
Local lRet 		:= .F.
Local cFile		:= ""
Local cTefDIR	:= "\AUTOCOM\TEF"+cEmpAnt+StrTran(Alltrim(cFilAnt)," ","")
Local nRet		:= -1
Local cArqRename:= ""

If lTEFSave
	
	cFile  := cTefDIR + "\" + cNumeOrc + ".CSV"
	cArqRename:= cTefDIR  + "\" + cNumeOrc + "_ARQUIVO_DELETADO_" + DtoS(dDataBase) + "_" + StrTran(Time(),":","") + ".CSV"
	
	If File( cFile )
		//nRet := FERASE(cFile) //Dabas  (Comentei este trecho temporariamente para o Projeto Todimo. Ao inves de apagar o arquivo, apenas o Renomeia para identificar que passou por esta funcao. Assim, mantemos o arquivo para eventuais consultas para identificar problemas. Futuramente sera sempre excluido o arquivo.)
		nRet := FRename(cFile , cArqRename)
		If nRet == -1
			LjGrvLog(cNumeOrc,"Ocorreu uma FALHA ao tentar apagar o arquivo ["+cFile+"] de recuperacao do TEF. [FError: "+ Str(FError(),4)+ "]")
			lRet := .F.
		Else
			LjGrvLog(cNumeOrc,"Apagou o arquivo ["+cFile+"] de recuperacao do TEF")
			lRet := .T.
		Endif
	Else
		LjGrvLog(cNumeOrc,"Arquivo [" + cFile + "] de recuperacao do TEF nao encontrado para realizar sua exclusao")
		lRet := .F.
	EndIf		

EndIf

Return lRet


//------------------------------------------------------------------------------------------------------------------------
/*/{Protheus.doc} LjExiTEF
Funcao para verificar se existe o arquivo de recuperação TEF
@author	fabiana.silva
@param     cNumeOrc - Numero do Orçamento
return    lRet Existe o arquivo de recuperação TEF
@version	P11.80
@since	01/06/2017
/*/
//------------------------------------------------------------------------------------------------------------------------
Function LjExiTEF(cNumeOrc)
Local lRet 		:= .F.
Local cFile		:= ""
Local cTefDIR	:= "\AUTOCOM\TEF"+cEmpAnt+StrTran(Alltrim(cFilAnt)," ","")

If lTEFSave .AND. !Empty(cNumeOrc)
	
	cFile  := cTefDIR + "\" + cNumeOrc + ".CSV"
	lRet := File(cFile)
	
EndIf

Return lRet

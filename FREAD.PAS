{ Floppy Read, by FreddyV Rev 1.0}

PROGRAM FREAD;

{$A+,Q-,R-,S-,I-} { IO Error does not stop the program }

Uses crt,BIOSDISK;

VAR
    FileName : String[8];
    DRVName: Char;
    DRVNb: Byte; {0:A, 1:B}

    DRVTypeNbCh : String;
    DRVTypeNb : Integer;

    i,Try:Byte;
    SCnt,TCnt,HCnt : Byte;
    SectorOk: Boolean;
    TrackSize: Word; { 512 * Sector per track }
    ErrorCount: Word;
    Conv : Integer;

    SaveAttr : Byte;

    IMGFile: File; { IMG  File definition }
    LOGFile: Text; { LOG File definition }
    ByteWritten : Word;

    UseBuffer1    : Boolean;  { If the Buffer 1 Cross boundaries, use the Buffer 2 }
    SectorBuffer1 : Byte9k;
    SectorBuffer2 : Byte9k;

TYPE

 Char11=Array[1..11] of Char;

 DiskInfos=Record
            N : Array[1..11] of Char;
            T : Byte;
            S : Byte;
            H : Byte;
          End;
CONST

FormatNb = 7;
Disks : Array[1..FormatNb] of DiskInfos =
       ((N:'360Kb 5"1/4' ;T:40; S:9  ;H:2),
        (N:'720Kb 3"1/2' ;T:80; S:9  ;H:2),
        (N:'1.2Mb 5"1/4' ;T:80; S:15 ;H:2),
        (N:'1.4Mb 3"1/2' ;T:80; S:18 ;H:2),
		(N:'160Kb 5"1/4' ;T:40; S:8  ;H:1),
		(N:'180Kb 5"1/4' ;T:40; S:9  ;H:1),
		(N:'320Kb 5"1/4' ;T:40; S:8  ;H:2));
 
PROCEDURE Fatal_Error(S:String);
Begin
Writeln;
Writeln(S);
Writeln(LOGFile,S);
Close(LOGFile);
Close(IMGFile);
End; 
 
Begin
SaveAttr:=TextAttr; { Save Color }
TextAttr:=$1F;
Write ('** FREAD By FreddyV, Rev 1.02 April 2021 **');
TextAttr:=SaveAttr; { Restore color }

Writeln;
Writeln ('Read a Floppy and save it to an .IMG File');
Writeln ('Read sector by sector and retry 5 Times, Use the standard BIOS 13h Interrupt.');
Writeln;

{ Define the Source }
Write('Enter the Drive name (Default A): ');
Readln(DRVName);
DRVNb:=0; { Default A }
If (DRVName='B') or (DRVName='b') then DRVNb:=1;

Writeln('');

For i:=1 to FormatNb do Writeln(i,': ',Disks[i].N,' ',Disks[i].H,':',Disks[i].T,':',Disks[i].S);

Write('Select the disk format (Default 1): ');
DRVTypeNb:=1; { Default 1 }
Readln(DRVTypeNbCh);

Val(DRVTypeNbCh,DRVTypeNb,Conv);
If (DRVTypeNb=0) or (DRVTypeNb>FormatNb) or (conv<>0) then
   DRVTypeNb:=1;

{ Define Target }
Writeln('');
Write('Enter the File name (Without extention): ');
fileName:='';
Readln(FileName);

Writeln('Start the copy from the floppy ',DRVNb,' Type ',Disks[DRVTypeNb].N);
Writeln('Press Escape to stop.');

Assign(IMGFile,Filename+'.IMG');
reset(IMGFile,1); {,1 for Byte length) }
If (IOResult<>0) then
  Begin
{ ** Start of the Copy ** }

{ * Create the files * }
   Writeln('Creating the ['+Filename+'.IMG] File');

   Assign(LOGFile,Filename+'.LOG');
   rewrite(LogFile);
   If (IOResult<>0) then
       Begin
	   Writeln('Error creating '+Filename+'.LOG File');
	   Exit;
	   End;   
   rewrite(IMGFile);
   If (IOResult<>0) then
       Begin
	   Writeln('Error creating '+Filename+'.IMG File');
	   Exit;
	   End;
   Close(IMGFile);
   reset(IMGFile,1); {,1 for Byte length) }
   
   Writeln (LOGFile,'** FREAD By FreddyV, Rev 1.0 April 2021 **');
   Writeln(LOGFile,'Copy from the floppy drive ',DRVNb);
   Writeln(LOGFile,'Disk format : ',Disks[DRVTypeNb].N,' ',Disks[DRVTypeNb].H,':',Disks[DRVTypeNb].T,':',Disks[DRVTypeNb].S);

   ErrorCount:=0;
   UseBuffer1:=True;
   TrackSize:=512*Disks[DRVTypeNb].S;

   BIOS_InitFloppy(DRVTypeNb);

   For TCnt:=0 to Disks[DRVTypeNb].T-1 do { Track Loop }
   For HCnt:=0 to Disks[DRVTypeNb].H-1 do { Head Loop (Read Track by Track) }
    Begin

     If Keypressed then
      If (Readkey=#27) then
         Begin
          Fatal_Error('Escape pressed.');			 
          Exit;
         End;
	
	 Gotoxy(1,Wherey);
	 Delline; { Clean the previous text }
	 Write('Reading Track ',TCnt,' Head ',HCnt);
     { * Read a Track * }
	  If UseBuffer1 then
        Begin
	     BIOS_FloppyReadSector(DRVNb,HCnt,TCnt,1,Disks[DRVTypeNb].S,SectorBuffer1);
		 If Floppy_Error=9 then
		    Begin
			 Writeln('DMA Error, change the Read Buffer');
			 UseBuffer1:=False;
			 BIOS_InitFloppy(DRVTypeNb);
			 BIOS_FloppyReadSector(DRVNb,HCnt,TCnt,1,Disks[DRVTypeNb].S,SectorBuffer2);
			End;
	    End
	     Else BIOS_FloppyReadSector(DRVNb,HCnt,TCnt,1,Disks[DRVTypeNb].S,SectorBuffer2);

     { * Write the Track * }

	 If Floppy_error=0 then
	    Begin
          If UseBuffer1 then BlockWrite(IMGFile,SectorBuffer1,TrackSize,ByteWritten)
	         Else BlockWrite(IMGFile,SectorBuffer2,TrackSize,ByteWritten);
          If ByteWritten<>TrackSize then
		     Begin
              Fatal_Error('Error during the file Write. (no more space ?)');			 
              Exit;			  
			 End
			 
			Else Write (' | Read Ok');
	    End
		Else { Error > Do Sector by Sector }
		 Begin
		 
          If Floppy_error in [1,$05,$07,$CC,$FF] Then
             Begin
              Writeln;
              Writeln('Fatal Error ',Floppy_error);
              Writeln(LOGFile,'Fatal Error ',Floppy_error);
              Close(LOGFile);
              Close(IMGFile);
              Exit;
             End;

          Writeln(' | Read Error Code ',Floppy_Error,'(BIOS)');
          Writeln('Read Sectors:');
          Writeln(LOGFile,'Track ',TCnt,' Read Error Code ',Floppy_Error,' (BIOS), Read Sector by Sector');
          For SCnt:=1 to Disks[DRVTypeNb].S do  { Loop Track by Track }
            Begin
	       Write (' ',SCnt,'-');
		   Try:=1;
		    Repeat
			
            If Keypressed then 
		       If (Readkey=#27) then
		         Begin
			      Fatal_Error('Escape pressed.');		 
			     Exit;
			    End;
				
		     { * Read one sector * }
			  BIOS_InitFloppy(DRVTypeNb); { Init after an error}
	          If UseBuffer1 then
                      BIOS_FloppyReadSector(DRVNb,HCnt,TCnt,SCnt,1,SectorBuffer1)
	             Else BIOS_FloppyReadSector(DRVNb,HCnt,TCnt,SCnt,1,SectorBuffer2);

             If (Floppy_error=0) then Write('R')
			    Else Write('E');
             Try:=Try+1;			   
	        Until ((Try>5) or (Floppy_error=0)); { Do 5 Trial Maximum per Sector}

		  If Floppy_error=0 then
			 Begin
			  If Try>2 then Writeln(LOGFile,'Pass after ',Try-1,' Trials (T:H:S) ',TCnt,':',HCnt,':',SCnt);
               SectorOk:=True;
             End;

         If (Floppy_Error=0) then Write('W')
             Else
             Begin
              ErrorCount:=ErrorCount+1;
              Writeln(LOGFile,'Error ',Floppy_error,' : Buffer content saved anyway (T:H:S) ',TCnt,':',HCnt,':',SCnt);
              { * Write one sector (Error)* }
             End;

         If UseBuffer1 then BlockWrite(IMGFile,SectorBuffer1,512,ByteWritten)
            Else BlockWrite(IMGFile,SectorBuffer2,512,ByteWritten);

         If ByteWritten<>512 then
		     Begin
              Fatal_Error('Error during the file Write. (no more space ?)');	 
              Exit;			  
			 End
		
	    End;  { SCnt }
        Writeln('');
       End;

    End;

   If UseBuffer1 then BIOS_FloppyReadSector(DRVNb,0,0,1,1,SectorBuffer1)
            Else BIOS_FloppyReadSector(DRVNb,0,0,1,1,SectorBuffer2);

   Writeln('');
   If ErrorCount=0 then
      Begin
       Writeln ('Copy completed without Error.');
       Writeln (LOGFile,'Copy completed without Error.');
	  End
	 Else
      Begin
       Writeln ('Copy completed with ',ErrorCount,' Error(s)');
       Writeln (LOGFile,'Copy completed with ',ErrorCount,' Error(s)');
      End;

   Close(LOGFile);
   Close(IMGFile);

  End
   Else Writeln('The File ',Filename,'.IMG already exist, Delete or rename it before proceeding.');

End.
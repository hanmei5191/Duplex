#!/usr/bin/bash
# files needed from Galaxy: 
# Galaxy3-[pBR322.fna].fasta
# Galaxy17-[Sequence_Content_Trimmer_on_data_13_and_data_12].fasta -> Galaxy20-[Sequence_Content_Trimmer_on_data_15_and_data_14].fasta
# Galaxy29-[SAM-to-BAM_on_data_3_and_data_28__converted_BAM].bam -> Galaxy43-[SAM-to-BAM_on_data_3_and_data_41__converted_BAM].bam
# Galaxy29-[SAM-to-BAM_on_data_3_and_data_28__converted_BAM].bai -> Galaxy43-[SAM-to-BAM_on_data_3_and_data_41__converted_BAM].bai
# Galaxy34-[Filter_on_data_33].tabular -> Galaxy53-[Filter_on_data_51].tabular
# 

dir=readsCallVariants
if [[ ! -e $dir ]]; then
    eval "mkdir $dir"
fi

awk '{if (NR!=1) print $3}' Galaxy53-[Filter_on_data_51].tabular > variantsCalled.txt 

awk 'BEGIN {OFS="\t"} />/ {print substr($1, 2, 24), $2}' Galaxy20-[Sequence_Content_Trimmer_on_data_15_and_data_14].fasta > familySizeTable.txt

while read cmd 
  do   

#We will lose some data in the next step if insertion/deletion exists.     
  samtools view -b Galaxy43-[SAM-to-BAM_on_data_3_and_data_41__converted_BAM].bam pBR322:$cmd-$cmd | samtools fillmd -e - Galaxy3-[pBR322.fna].fasta | grep -v "^@"| awk -v pos=$cmd 'BEGIN {OFS = FS = "\t" } ; {n=split($10,a,""); print pos,(pos-$4)+1, a[(pos-$4)+1], $1, $4, $10 }' | awk 'BEGIN{OFS="\t";while(getline<"familySizeTable.txt"){t=$1;$1="";sz[t]=$0;gsub(/^[ \t]+/,"",sz[t])}} {print $1,$2,$3,$4,sz[$4],$5,$6}' > $dir/${cmd}_readsCallVariants_tmp.txt 

#The follwoing awk corrects variant (col3) in *readsCallVariants.txt. 
  awk 'BEGIN{OFS="\t";print "position distanceFromReadStart variant readName familySize readStart read"}{align = $7;sub(/^[ATCGN]*/,"",$7)} {print $1,$2,substr($7, $2, 1),$4,$5,$6,align}' $dir/${cmd}_readsCallVariants_tmp.txt > $dir/${cmd}_readsCallVariants.txt

  rm $dir/${cmd}_readsCallVariants_tmp.txt 

  done < variantsCalled.txt

cd readsCallVariants

for entry in `ls *readsCallVariants.txt`; 
  do
    echo $entry
    #This awk filter out mapped alignment, and write remaining unmapped reads into a tmp file named 'tmp1.txt'. 
    awk '{if (NR!=1 && $3!="N" && $3~/[ATCG]/) print $0}' $entry > tmp1.txt 
    
    #The following python script write family sizes of all variants into a file named famSizeVar.txt.  
    python ../famSizeConcaNote_0725.py 
    #The following python script write linkage files into a file named 
    python ../linkageCalling_0726.py 
#    sleep 0.2
    
    rm tmp1.txt
    
#    sleep 0.2
  done

#Before do the following awk, remove lines with bias > 1 in ../Galaxy53-[Filter_on_data_51].tabular
awk 'BEGIN{while(getline<"../famSizeVar.txt"){t=$1;sz[t]=$2}} {print $0"\t"sz[$3]}' ../Galaxy53-[Filter_on_data_51].tabular > ../varWithFam.txt 

sort -u -k2,2 ../linkage.txt > ../linkage_sort.txt

cd ../
rm linkage.txt famSizeVar.txt
rm variantsCalled.txt familySizeTable.txt 

python linkSplit_0728.py 
awk 'BEGIN{while(getline<"Galaxy53-[Filter_on_data_51].tabular"){t=$3;sz[t]=$16}} {split($1,a,"_");split(a[1],b,"-");split(a[2],c,"-");  print $1"\t"sz[b[1]]"\t"sz[c[1]]"\t"$2"\t"$3"\t"$4"\t"$5}' linkage_twoSites.txt > linkage_reads_MAF.txt

rm linkage_twoSites.txt varWithFam.txt 

#awk 'BEGIN{while(getline<"../Galaxy53-[Filter_on_data_51].tabular"){t=$3;sz[t]=$12;gsub(/^[ \t]+/,"",sz[t])}} {print $1"\t"sz[$1]"\t"$2"\t"$3}' famSizeVar.txt> output.txt 

rm -rf readsCallVariants

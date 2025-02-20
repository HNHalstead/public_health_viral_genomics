version 1.0

task deidentify {

  input {
    String    samplename
    String    submission_id
    File      sequence

    String    docker_image = "staphb/seqyclean:1.10.09"
    Int       mem_size_gb = 3
    Int       CPUs = 1
    Int       disk_size = 100
    Int       preemptible_tries = 0
  }

  command {
    # de-identified consensus/assembly sequence
    echo ">${submission_id}" > ${submission_id}.fasta
    grep -v ">" ${sequence} >> ${submission_id}.fasta

    num_N=$( grep -v ">" ${sequence} | grep -o 'N' | wc -l )
    if [ -z "$num_N" ] ; then num_N="0" ; fi
    echo $num_N | tee NUM_N

    num_ACTG=$( grep -v ">" ${sequence} | grep -o -E "C|A|T|G" | wc -l )
    if [ -z "$num_ACTG" ] ; then num_ACTG="0" ; fi
    echo $num_ACTG | tee NUM_ACTG

    num_total=$( grep -v ">" ${sequence} | grep -o -E '[A-Z]' | wc -l )
    if [ -z "$num_total" ] ; then num_total="0" ; fi
    echo $num_total | tee NUM_TOTAL
  }

  output {
    File      deID_assembly = "${submission_id}.fasta"
    Int       number_N = read_string("NUM_N")
    Int       number_ATCG = read_string("NUM_ACTG")
    Int       number_Total = read_string("NUM_TOTAL")
  }

  runtime {
      docker:       docker_image
      memory:       "~{mem_size_gb} GB"
      cpu:          CPUs
      disks:        "local-disk ~{disk_size} SSD"
      preemptible:  preemptible_tries
      maxRetries:   3
  }
}

task gisaid {

  input {
    String    samplename
    String    submission_id
    String    collection_date
    File      sequence
    String    iso_host
    String    iso_country

    String    gisaid_submitter
    String    iso_state
    String    iso_continent
    String    seq_platform
    String    assembly_method
    String    originating_lab
    String    origLab_address
    String    submitting_lab
    String    subLab_address
    String    Authors

    String    passage_details="Original"
    String    gender="unknown"
    String    patient_age="unknown"
    String    patient_status="unknown"
    String    specimen_source=""
    String    outbreak=""
    String    last_vaccinated=""
    String    treatment=""
    String    iso_county = ""

    String    docker_image = "staphb/seqyclean:1.10.09"
    Int       mem_size_gb = 3
    Int       CPUs = 1
    Int       disk_size = 10
    Int       preemptible_tries = 0
  }

  command {
    # de-identified consensus/assembly sequence
    year=$(echo ${collection_date} | cut -f 1 -d '-')
    echo ">hCoV-19/${iso_country}/${submission_id}/$year" > ${submission_id}.gisaid.fa
    grep -v ">" ${sequence} >> ${submission_id}.gisaid.fa


    echo submitter,fn,covv_virus_name,covv_type,covv_passage,covv_collection_date,covv_location,covv_add_location,covv_host,covv_add_host_info,covv_sampling_strategy,covv_gender,covv_patient_age,covv_patient_status,covv_specimen,covv_outbreak,covv_last_vaccinated,covv_treatment,covv_seq_technology,covv_assembly_method,covv_coverage,covv_orig_lab,covv_orig_lab_addr,covv_provider_sample_id,covv_subm_lab,covv_subm_lab_addr,covv_subm_sample_id,covv_authors,covv_comment,comment_type >  ${submission_id}.gisaidMeta.csv

    echo Submitter,FASTA filename,Virus name,Type,Passage details/history,Collection date,Location,Additional location information,Host,Additional host information,Sampling Strategy,Gender,Patient age,Patient status,Specimen source,Outbreak,Last vaccinated,Treatment,Sequencing technology,Assembly method,Coverage,Originating lab,Address,Sample ID given by the sample provider,Submitting lab,Address,Sample ID given by the submitting laboratory,Authors,Comment,Comment Icon >> ${submission_id}.gisaidMeta.csv

    echo "\"${gisaid_submitter}\",\"${submission_id}.gisaid.fa\",\"hCoV-19/${iso_country}/${submission_id}/$year\",\"betacoronavirus\",\"${passage_details}\",\"${collection_date}\",\"${iso_continent} / ${iso_country} / ${iso_state} / ${iso_county}\" ,,\"${iso_host}\",,,\"${gender}\",\"${patient_age}\",\"${patient_status}\",\"${specimen_source}\",\"${outbreak}\",\"${last_vaccinated}\",\"${treatment}\",\"${seq_platform}\",\"${assembly_method}\",,\"${originating_lab}\",\"${origLab_address}\",,\"${submitting_lab}\",\"${subLab_address}\",,\"${Authors}\"",, >> ${submission_id}.gisaidMeta.csv

  }

  output {
    File     gisaid_assembly = "${submission_id}.gisaid.fa"
    File     gisaid_metadata = "${submission_id}.gisaidMeta.csv"
  }

  runtime {
      docker:       docker_image
      memory:       "~{mem_size_gb} GB"
      cpu:          CPUs
      disks:        "local-disk ~{disk_size} SSD"
      preemptible:  preemptible_tries
      maxRetries:   3
  }
}

task genbank {

  input {
    String    samplename
    String    submission_id
    String    collection_date
    File      sequence
    String    organism
    String    iso_org
    String    iso_host
    String    iso_country
    String    specimen_source
    String    BioProject

    String    docker_image = "theiagen/utility:1.1"
    Int       mem_size_gb = 3
    Int       CPUs = 1
    Int       disk_size = 10
    Int       preemptible_tries = 0
  }

  command <<<
    year=$(echo ~{collection_date} | cut -f 1 -d '-')
    isolate=$(echo ~{submission_id} | awk 'BEGIN { FS = "-" } ; {$1=$2=""; print $0}' | sed 's/^ *//g')

    # removing leading Ns, folding sequencing to 75 bp wide, and adding metadata for genbank submissions
    echo ">~{submission_id} [organism=~{organism}][isolate=~{iso_org}/~{iso_host}/~{iso_country}/~{submission_id}/~year)][host=~{iso_host}][country=~{iso_country}][collection_date=~{collection_date}]" > ~{submission_id}.genbank.fa
    grep -v ">" ~{sequence} | sed 's/^N*N//g' | fold -w 75 >> ~{submission_id}.genbank.fa

    echo Sequence_ID,Country,Host,Isolate,Collection Date, BioProject Accession > ~{submission_id}.genbankMeta.csv

    echo "\"~{submission_id}\",\"~{iso_country}\",\"~{iso_host}\",\"~{submission_id}\",\"~{collection_date}\",\"~{BioProject}\"" >> ~{submission_id}.genbankMeta.csv

  >>>

  output {
    File     genbank_assembly = "~{submission_id}.genbank.fa"
    File     genbank_metadata = "~{submission_id}.genbankMeta.csv"
  }

  runtime {
      docker:       docker_image
      memory:       "~{mem_size_gb} GB"
      cpu:          CPUs
      disks:        "local-disk ~{disk_size} SSD"
      preemptible:  preemptible_tries
      maxRetries:   3
  }
}

task sra {

  input {
    String    submission_id
    File      reads

    String    docker_image = "staphb/seqyclean:1.10.09"
    Int       mem_size_gb = 1
    Int       CPUs = 1
    Int       disk_size = 25
    Int       preemptible_tries = 0
  }

  command {
    cp ${reads} ${submission_id}.fastq.gz
  }

  output {
    File?    reads_submission = "${submission_id}.fastq.gz"
  }

  runtime {
      docker:       docker_image
      memory:       "~{mem_size_gb} GB"
      cpu:          CPUs
      disks:        "local-disk ~{disk_size} SSD"
      preemptible:  preemptible_tries
      maxRetries:   3
  }
}


task compile {

  input {
    Array[File]   single_submission_fasta
    Array[File]   single_submission_meta
    Array[String] samplename
    Array[String] submission_id
    Array[String] vadr_num_alerts
    Int           vadr_threshold=0
    String        repository
    String        docker_image = "theiagen/utility:1.1"
    Int           mem_size_gb = 1
    Int           CPUs = 1
    Int           disk_size = 25
    Int           preemptible_tries = 0
  }

  command <<<
  assembly_array=(~{sep=' ' single_submission_fasta})
  assembly_array_len=$(echo "${#assembly_array[@]}")
  meta_array=(~{sep=' ' single_submission_meta})
  meta_array_len=$(echo "${#meta_array[@]}")
  vadr_string="~{sep=',' vadr_num_alerts}"
  IFS=',' read -r -a vadr_array <<< ${vadr_string}
  vadr_array_len=$(echo "${#vadr_array[@]}")
  samplename_array=(~{sep=' ' samplename})
  submission_id_array=(~{sep=' ' submission_id})
  submission_id_array_len=$(echo "${#submission_id_array[@]}")
  vadr_array_len=$(echo "${#vadr_array[@]}")
  passed_assemblies=""
  passed_meta=""

  #Create files to capture batched and excluded samples
  echo -e "~{repository} Identifier\tSamplename\tNumber of Vadr Alerts\tNote" > ~{repository}_batched_samples.tsv
  echo -e "~{repository} Identifier\tSamplename\tNumber of Vadr Alerts\tNote" > ~{repository}_excluded_samples.tsv

  # Ensure assembly, meta, and vadr arrays are of equal length
  if [ "$submission_id_array" -ne "$vadr_array_len" ]; then
    echo "Submission_id array (length: $assembly_array_len) and vadr array (length: $vadr_array_len) are of unequal length." >&2
    exit 1
  fi

  # remove samples that excede vadr threshold
  for index in ${!submission_id_array[@]}; do
    submission_id=${submission_id_array[$index]}
    samplename=${samplename_array[$index]}
    vadr=${vadr_array[$index]} 
    batch_note=""
    
    # check if the sample has submittable assembly file; if so remove those that excede vadr thresholds
    assembly=$(printf '%s\n' "${assembly_array[@]}" | grep "${submission_id}")
    metadata=$(printf '%s\n' "${meta_array[@]}" | grep "${submission_id}")

    echo -e "Submission_ID: ${submission_id}\n\tAssembly: ${assembly}\n\tMetadata: ${metadata}\n\tVADR: ${vadr}"

    if [ \( ! -z "${assembly}" \) -a \( ! -z "{$metadata}" \) ]; then
      repository_identifier=$(grep -e ">" ${assembly} | sed 's/\s.*$//' | sed 's/>//g' )  
      re='^[0-9]+$'
      if ! [[ "${vadr}" =~ $re ]] ; then
        batch_note="No VADR value to evaluate"
        echo -e "\t$submission_id removed: ${batch_note}"
        echo -e "$repository_identifier\t$samplename\t$vadr\t$batch_note" >> ~{repository}_excluded_samples.tsv
      elif [ "${vadr}" -le "~{vadr_threshold}" ] ; then
        passed_assemblies=( "${passed_assemblies[@]}" "${assembly}")
        passed_meta=( "${passed_meta[@]}" "${metadata}")
        echo -e "\t$submission_id added to batch"
        echo -e "$repository_identifier\t$samplename\t$vadr\t$batch_note" >> ~{repository}_batched_samples.tsv        
      else 
        batch_note="Number of vadr alerts (${vadr}) exceeds threshold ~{vadr_threshold}"
        echo -e "\t$submission_id removed: ${batch_note}"
        echo -e "$repository_identifier\t$samplename\t$vadr\t$batch_note" >> ~{repository}_excluded_samples.tsv
      fi
    else 
      batch_note="Assembly or metadata file missing" 
      repository_identifier="NA"
      echo -e "\t$submission_id removed: ${batch_note}"
      echo -e "$repository_identifier\t$samplename\t$vadr\t$batch_note" >> ~{repository}_excluded_samples.tsv
    fi

  done

  count=0
  for i in ${passed_meta[*]}; do
      # grab header from first sample in meta_array
      while [ "$count" -lt 1 ]; do
        head -n -1 $i > ~{repository}_upload_meta.csv
        count+=1
      done
      #populate csv with each samples metadata
      sed 's+",\".*\.gisaid\.fa+\",\"GISAID_upload.fasta+g' $i | tail -n1  >> ~{repository}_upload_meta.csv
  done

  cat ${passed_assemblies[*]} > ~{repository}_upload.fasta

  >>>

  output {
    File?   upload_meta   = "${repository}_upload_meta.csv"
    File?   upload_fasta  = "${repository}_upload.fasta"
    File    batched_samples = "${repository}_batched_samples.tsv"
    File    excluded_samples = "${repository}_excluded_samples.tsv"

  }

  runtime {
      docker:       docker_image
      memory:       "~{mem_size_gb} GB"
      cpu:          CPUs
      disks:        "local-disk ~{disk_size} SSD"
      preemptible:  preemptible_tries
      maxRetries:   3
  }
}

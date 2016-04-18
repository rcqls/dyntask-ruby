# encoding: UTF-8
require 'dyndoc-software'
require 'dyndoc-converter'
require "fileutils"
require 'pathname'

module DynTask

  @@task_mngr=nil
  @@task_cpt=-1

  def self.inc_task_cpt
    ((@@task_cpt += 1) == 9999 ? (@@task_cpt = 0) : @@task_cpt)
  end

  def self.add_task(task,id=nil) #id.nil? => new task
    @@task_mngr ||= DynTask::TaskMngr.new
    @@task_mngr.add_task(task,id)
  end

  def self.save_tasks(task_basename,task_dirname=nil)
    return unless @@task_mngr
    @@task_mngr.save_tasks(task_basename,task_dirname)
  end

  def self.read_tasks(task_filename)
    @@task_mngr ||= DynTask::TaskMngr.new
    @@task_mngr.load_user_task_plugins
    @@task_mngr.read_tasks(task_filename)
  end

  @@cfg_dir=nil

  def self.cfg_dir
    return @@cfg_dir if @@cfg_dir
    root=File.join(ENV["HOME"],".dyntask")
    ## the idea is that any path has to be relative to some system root
    sys_root=(ENV["HOMEDRIVE"]||"")+"/" # local mode
    @@cfg_dir={
      :root => root,
      :etc => File.join(root,"etc"),
      :share => File.join(root,"share"),
      :tasks => File.join(root,"share","tasks"),
      :plugins => File.join(root,"share","plugins"),
      :run => File.join(root,"run") # default folder to watch. In a perfect world (this is my goal), only this folder to watch!
    }
    ## File containing the sys_root_path (used in atom package)
    @@cfg_dir[:sys_root_path_cfg]=File.join(@@cfg_dir[:etc],"sys_root_path")
    self.update_sys_root(sys_root)
    @@cfg_dir
  end

  ## to be able to change sys_root path depending on local or remote mode
  def self.update_sys_root(path)
    @@cfg_dir[:sys_root]=path
    ## save sys_root_path to some config file (used in atom package)
    FileUtils.mkdir_p File.dirname(@@cfg_dir[:sys_root_path_cfg])
    File.open(@@cfg_dir[:sys_root_path_cfg],"w") do |f|
      f << @@cfg_dir[:sys_root]
    end
  end

  def self.sys_root_path(rel_path)
    File.expand_path File.join(self.cfg_dir[:sys_root],rel_path)
  end

  def self.relative_path_from_sys_root(abs_path)
    begin
      #p abs_path
      #p self.cfg_dir[:sys_root]
      ap=Pathname.new(abs_path).realpath
      #p ap
      ap.relative_path_from(Pathname.new(self.cfg_dir[:sys_root])).to_s
    rescue
      nil
    end
  end

  @@cfg_pandoc=nil

  def self.cfg_pandoc(renew=false)
    return @@cfg_pandoc if @@cfg_pandoc and !renew
    @@cfg_pandoc={}
    @@cfg_pandoc[:extra_etc]=File.join(self.cfg_dir[:etc],"pandoc_extra_dir")
    @@cfg_pandoc[:extra_dir]=((File.exist? @@cfg_pandoc[:extra_etc]) ? File.read(@@cfg_pandoc[:extra_etc]) : File.join(self.cfg_dir[:root],"pandoc-extra")).strip
    @@cfg_pandoc[:config_rb]=File.join(self.cfg_dir[:share],"pandoc","config.rb")
    @@cfg_pandoc[:extra]=(File.exist? @@cfg_pandoc[:config_rb]) ? Object.class_eval(File.read(@@cfg_pandoc[:config_rb])) : {}
    @@cfg_pandoc
  end

  def self.wait_for_file(filename,wait_loop_number = 20, wait_loop_time = 0.5,verbose=false)
    cpt=0
    while !File.exists? filename and cpt < wait_loop_number
      p "wait: #{cpt}"
      sleep wait_loop_time
      cpt+=1
    end
    ## return succeed
    File.exists? filename
  end

  class TaskMngr

    # TODO: to put outside to be extended by users!
    TASKS=["pdflatex","pandoc","png","dyn","sh","dyn_cli"]
    TASK_EXT=".task_"

    def initialize
      init_tasks
    end

     def init_tasks
      @task_ids={}
    end

    ## Comment on writing task:
    ## task is just a ruby hash containing at least :cmd key to describe the
    ## command type. Other keys are for completing the task related to command :cmd
    ## However, :source and :target are recommanded keynames for describing source and target filename

    ## possibly add condition to check before applying command+options
    def add_task(task,id=nil)
      task_cpt=id || DynTask.inc_task_cpt
      @task_ids[task_cpt] = [] unless @task_ids[task_cpt]
      @task_ids[task_cpt] << task
      task_cpt #id of the task
    end

    ##
    def save_tasks(id,task_basename,task_dirname=nil)
      task_dirname=DynTask.cfg_dir[:run] unless task_dirname
      task_dirname=File.expand_path task_dirname
      FileUtils.mkdir_p task_dirname unless File.directory? task_dirname
      if (tasks_to_save=@task_ids[id])
        ## delegate id
        tasks_to_save[0][:id]=id
        ## write next tasks to file
        task_filename=File.join(task_dirname,("%04d" % id)+"_"+task_basename+TASK_EXT+tasks_to_save[0][:cmd].to_s)
        File.open(task_filename,"w") do |f|
          f << tasks_to_save.inspect
        end
      else
        puts "DynTask WARNING: Nothing to save!"
      end
    end

    def write_tasks(task_basename,tasks)
      @tasks=tasks
      id=DynTask.inc_task_cpt
      save_tasks(id,task_basename)
    end

    ## workdir is now specified which is relative to some root directory
    ## Two modes:
    ## 1) centralized mode (defaul): ~/.dyntask/run folder watched with root specified in ~/.dyntask/etc/sys_root_path
    ## Nice when used everywhere in your local computer
    ## 2) decentralized mode: every watched directory is a working directory
    ## Nice when certain tasks can be performed remotely.

    ## maybe to maintain only one task, remove current task when the new one is created
    def read_tasks(task_filename)
      @task_filename=task_filename
      @tasks=Object.class_eval(File.read(@task_filename).force_encoding("utf-8"))
      ##p @tasks
      if @tasks.length>=1
        @task=@tasks.shift #first task to deal with
        ##p @task
        if @task[:workdir]
          # if workdir is specified inside the first task (almost required now)
          @workdir = @task[:workdir]
          dirname_next_task=nil #means default mode (from sys_root_path)
          if @workdir == :current #mode current
            @workdir=File.dirname(File.expand_path(@task_filename))
            dirname_next_task=@workdir
          else #mode
            # workdir is always relative from sys_root which could differ depending on the computer (or vm)
            @workdir = DynTask.sys_root_path(@workdir)
          end
          if File.exist? @workdir

            make_task
            if @tasks.length>=1
              dirname=File.dirname(task_filename)
              basename=File.basename(task_filename,".*")
              task_basename=File.join(dirname,basename)
              save_tasks(@task[:id],task_basename,dirname_next_task) # same id since it is a chaining (TO CHECK: when remote action maybe prefer uuid instead of counter to gnerate id)
            end
            # remove since it is executed!
            FileUtils.rm(task_filename)
          end
        end
      end
    end

    ## if option to not remove taskfiles, this is a clean!
    # def task_clean_taskfiles(task_filename)
    #   dirname=File.dirname(task_filename)
    #   basename=File.basename(task_filename,TASK_EXT+"*")
    #
    #   Dir[File.join(dirname,basename+TASK_EXT+"*")].each do |f|
    #     FileUtils.rm(f)
    #   end
    # end

    def load_user_task_plugins
      Dir[File.join(DynTask.cfg_dir[:plugins],"*.rb")].each {|lib| require lib} if File.exists? DynTask.cfg_dir[:plugins]
    end

    def info_file(filename)
      return {} unless filename

      ##p [:info_file,filename]

      res = {
        dirname: File.dirname(filename),
        extname: File.extname(filename),
        basename: File.basename(filename,".*")
      }
      res[:filename]=res[:basename]+res[:extname]
      res[:full_filename]=File.join(res[:dirname],res[:filename])
      res
    end

    def make_task

      ##
      @source=info_file(DynTask.sys_root_path(@task[:source]))
      #p [:info,@task[:source]]

      #p [:source,@source]
      @basename=@source[:basename]
      @extname=@source[:extname]
      @dirname=@source[:dirname]
      @filename=@source[:filename]

      @target=info_file(@task[:target]) if @task[:target]

      cd_new

      ## This is a rule, if a @task contains both :source and :content
      ## then save the file @task[:source] with this content @task[:content]
      ## This is useful when delegating a next task in some dropbox-like environment: task and source are synchronized!
      if @task[:content] and @task[:source]
        #p [:content,@source[:filename]]
        File.open(@source[:filename],"w") do |f|
          f << @task[:content]
        end
      end

      method("make_"+@task[:cmd].to_s).call

      # case @task[:cmd].to_s
      # when "sh"
      #   make_sh
      # when "dyn"
      #   make_dyn
      # when "pdflatex"
      #   make_pdf
      # when "pandoc"
      #   make_pandoc
      # when "png"
      #   make_png
      # end

      cd_old

    end

    def cd_new
      @curdir=Dir.pwd
      Dir.chdir(@workdir)
    end

    def cd_old
      Dir.chdir(@curdir)
    end

    # make sh

    def make_sh
      shell_opts=@task[:shell_opts] || ""
      script_opts=@task[:script_opts] || ""
      `sh #{shell_opts} #{source[:filename]} #{script_opts}`
    end

    # make dyn

    def make_dyn
      opts = @task[:options] || ""
      p [:dyn_cmd,"dyn #{opts} #{@filename}"]
      `dyn #{opts} #{@filename}`
    end

    # make dyn-cli

    def make_dyn_cli
      p [:dyn_cmd_cli,"dyn-cli #{@filename} #{@target[:filename]} "]
      `dyn-cli #{@filename} #{@target[:filename]}`
    end

    # make pdf

    def make_pdflatex
      #p [:task,@task]
      nb_pass = @task[:nb_pass] || 1
      echo_mode=@task[:echo] || false

      ## Just in case of synchronisation delay!
      wait_time=@task[:wait_loop_time] || 0.5
      wait_nb=@task[:wait_loop_nb] || 20
      ok=DynTask.wait_for_file(@basename+".tex",wait_nb,wait_time)

      if ok
        nb_pass.times {|i| make_pdflatex_pass(echo_mode) }
      else
        puts "Warning: no way to apply pdflatex since #{@basename+'.tex'} does not exist!"
      end
    end

    # make pdflatex

    def make_pdflatex_pass(echo_mode=false)
      unless File.exists? @basename+".tex"
        msg="No pdflatex #{@basename} in #{@workdir} since file does not exist!"
        print "\n==> "+msg
      end
      if File.read(@basename+".tex").empty?
        msg="No pdflatex #{@basename} in #{@workdir} since empty file!"
        print "\n==> "+msg
        ###$dyn_logger.write("ERROR pdflatex: "+msg+"\n") unless Dyndoc.cfg_dyn[:dyndoc_mode]==:normal
        return ""
      end
      print "\n==> #{Dyndoc.pdflatex} #{@basename} in #{@workdir}"

      out=`#{Dyndoc.pdflatex} -halt-on-error -file-line-error -interaction=nonstopmode #{@basename}`
      out=out.b if RUBY_VERSION >= "1.9" #because out is not necessarily utf8 encoded
      out=out.split("\n")
      puts out if echo_mode
      if out[-2].include? "Fatal error"
        #if Dyndoc.cfg_dyn[:dyndoc_mode]==:normal
        #  print " -> NOT OKAY!!!\n==> "
        #  puts out[-4...-1]
        #  raise SystemExit
        #end
      else
        print " -> OKAY!!!\n"
        ###@cfg[:created_docs] << @basename+".pdf" #( @dirname.empty? ? "" : @dirname+"/" ) + @basename+".pdf"
      end
    end

    # make pandoc

    def make_pandoc

      cfg_pandoc = DynTask.cfg_pandoc[:extra]

      format_doc,format_output=@task[:filter].split("2")
      #
      p [format_doc.to_s , format_output.to_s]
      append_doc= @task[:append_doc] || ""
      cmd_pandoc_options,pandoc_file_output,pandoc_file_input=[],"",nil
      case @task[:filter]
      when "md2odt"
        cmd_pandoc_options = cfg_pandoc["md2odt"] || []
        pandoc_file_output=@basename+append_doc+".odt"
      when "md2docx"
        cmd_pandoc_options= cfg_pandoc["md2docx"] || ["-s","-S"]
        pandoc_file_output=@basename+append_doc+".docx"
      when "tex2docx"
        pandoc_file_input=@filename
        cmd_pandoc_options= cfg_pandoc["tex2docx"] || ["-s"]
        pandoc_file_output=@basename+append_doc+".docx"
      when "md2beamer"
        cmd_pandoc_options= cfg_pandoc["md2beamer"] || ["-t","beamer"]
        pandoc_file_output=@basename+append_doc+".pdf"
      when "md2dzslides"
        cmd_pandoc_options= cfg_pandoc["md2dzslides"] || ["-s","--mathml","-i","-t","dzslides"]
        pandoc_file_output=@basename+append_doc+".html"
      when "md2slidy"
        cmd_pandoc_options= cfg_pandoc["md2slidy"] || ["-s","--webtex","-i","-t","slidy"]
        pandoc_file_output=@basename+append_doc+".html"
      when "md2s5"
        cmd_pandoc_options= cfg_pandoc["md2s5"] || ["-s","--self-contained","--webtex","-i","-t","s5"]
        pandoc_file_output=@basename+append_doc+".html"
      when "md2revealjs"
        cmd_pandoc_options= cfg_pandoc["md2revealjs"] || ["-s","--self-contained","--webtex","-i","-t","revealjs"]
        pandoc_file_output=@basename+append_doc+".html"
      when "md2slideous"
        cmd_pandoc_options=["-s","--mathjax","-i","-t","slideous"]
        pandoc_file_output=@basename+append_doc+".html"
      end

      opts=cmd_pandoc_options #OBSOLETE NOW!: +["-o",pandoc_file_output]

      output=if pandoc_file_input
        opts << pandoc_file_input
        Dyndoc::Converter.pandoc(nil,opts.join(" "))
      else
        @content=@task[:content]
        #
        p [:make_pandoc_content, opts.join(" "),@content]
        Dyndoc::Converter.pandoc(@content,opts.join(" "))
      end

      if pandoc_file_output
        File.open(pandoc_file_output,"w") do |f|
          f << output
        end
      end

    end



    # make png

    def make_png
      make_dvipng
    end

    # make latex and dvipng

    def make_dvipng
        system "latex #{@basename}.tex"
        print "\nlatex #{@basename}.tex -> ok\n"
        system "dvipng --nogssafer #{@basename}.dvi -o #{@basename}.png"
        print "\ndvipng --nogssafer #{@basename}.dvi -o #{@basename}.png -> ok\n"
    end

    # make ttm

    def make_ttm
#puts "make_ttm:begin"
      Dyndoc::Converter.ttm(File.read(@task[:filename]).force_encoding("utf-8"))
    end

  end
end

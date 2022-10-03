
library(gdxrrw)
library(ggplot2)
library(reshape2)
library(xtable)
library(viridis)
library(RColorBrewer)
library(cowplot)

igdx('C:/GAMS/win64/24.2')

# grab absolute path to source file
thisFile <- function() {
  cmdArgs <- commandArgs(trailingOnly = FALSE)
  needle <- "--file="
  match <- grep(needle, cmdArgs)
  if (length(match) > 0) {
    # Rscript
    return(normalizePath(sub(needle, "", cmdArgs[match])))
  } else {
    # 'source'd via R console
    return(normalizePath(sys.frames()[[1]]$ofile))
  }
}

# store trailing command line arguments
args <- commandArgs(TRUE)

# Argument list input order:
# 1) scenario %scn%


# use to show color codes for R defaults
#library(scales)
#show_col(hue_pal()(3))
#show_col(hue_pal()(4))

if (length(args)==0){
  scn = "BAU_putty"
  reg = "census"
}else{
  scn = args[1]
  reg = args[2]
}


# script_path = dirname(thisFile()) 
script_path = getwd()

# create new plots director for scn
plots_path = file.path(script_path,"plots")
dir.create(plots_path)
dir.create(file.path(plots_path,paste0(scn,'_',reg)))

# point to gdx input file
gdx_dir = file.path(script_path,"gdx")
gdx_file = paste0("mgeout_",reg,"_",scn,".gdx")
gdx_path = file.path(gdx_dir,gdx_file)

# load gdx parameters
r_elec = rgdx.param(gdx_path,"r_elec")
r_rep = rgdx.param(gdx_path,"rep")
r_wdecomp = rgdx.param(gdx_path,"wdecomp")
r_gdp = rgdx.param(gdx_path,"r_gdp")
ibar = rgdx.param(gdx_path,"ibar_gen0")
fbar = rgdx.param(gdx_path,"fbar_gen0")
# cshr = rgdx.param(gdx_path,"cs_posttax")
cshr = rgdx.param(gdx_path,"cshr_ele0")
egtshr = rgdx.param(gdx_path,"gen_shr")

colnames(r_elec) = c("r","s","egt","t","cat","var","scn","val")
colnames(r_rep) = c("r","g","t","var","scn","val")
colnames(r_wdecomp) = c("scn","units","type","r","h","t","var","val")
colnames(r_gdp) = c("scn","units","type","r","t","var","val")
colnames(ibar) = c("r","g","egt","val")
colnames(fbar) = c("r","g","egt","val")
colnames(cshr) = c("r","g","egt","val")
cbar = rbind(ibar,fbar)
colnames(egtshr) = c("r","egt","val")

r_elec$t = as.numeric(as.character(r_elec$t))
r_rep$t = as.numeric(as.character(r_rep$t))
r_wdecomp$t = as.numeric(as.character(r_wdecomp$t))
r_gdp$t = as.numeric(as.character(r_gdp$t))


# Set definition
if (reg=="census"){
  regions = c("NEG","MID","ENC","WNC","SAC","ESC","WSC","MTN","PAC")
}else{
  regions = c("CA","TX","NY","WY","WV","PA","FL","AZ","ND","CO","IL","OH")
}

regions_ord = order(regions)
regions_ord = regions[regions_ord]
regions = regions_ord

sect_acr = c("oil","cru","gas","col","ele","trn","con","eint","omnf","osrv","roe","fd")
sect_full = c("Refined Oil","Crude Oil","Natural Gas","Coal","Electricity","Transportation","Construction","Energy Intensive","Other Manuf.","Other Services","Rest-of-economy","Final Cons.")

goods_acr = c("oil","cru","gas","col","ele","trn","con","eint","omnf","osrv","roe","fr","k","l")
goods_full = c("Refined Oil","Crude Oil","Natural Gas","Coal","Electricity","Transportation","Construction","Energy Intensive","Other Manuf.","Other Services","Rest-of-economy","Fixed Res.","Capital","Labor")

egt_acr = c("vre-wnd","vre-sol","conv-gas","conv-coal","conv-oth","conv-nuc","conv-hyd")
egt_full = c("Wind","Solar","Gas","Coal","Other","Nuclear","Hydro")


# example of how to use
# rep_em_shr$s = factor(rep_em_shr$s, levels=sect_acr, labels=sect_full)

# plot settings
# plot_specs =   theme_bw() + 
#   theme(legend.position = "bottom")

plot_specs =   theme_bw() + 
  theme(legend.position = "bottom") +
  theme(axis.text.x = element_text(size = 8))

cshr = subset(cshr,g %in% goods_acr)
cshr$g = factor(cshr$g, levels=goods_acr, labels=goods_full)
cshr = subset(cshr, r %in% regions)
cshr$r = factor(cshr$r, levels = regions_ord, labels = regions)

cshr = subset(cshr, egt %in% egt_acr)
cshr$egt = factor(cshr$egt, levels = egt_acr, labels = egt_full)

p_cshr <- ggplot(cshr, aes(val,egt,fill=g)) +
  geom_bar(stat = "identity", color = "black") +
  scale_fill_brewer(palette = "Set2") +
  theme_bw() + 
  theme(legend.position = "bottom") +
  theme(axis.text.x = element_text(size = 6)) +
  theme(axis.text.y = element_text(size = 7)) +
  theme(legend.text=element_text(size=6)) +
  facet_wrap(~r) +
  labs(title="U.S. Benchmark Input Demand by Generation Technology",
       subtitle="Share of total cost",
       x = "Share of total cost",
       y = "Generation Fuel Source",
       fill = "Input")
p_cshr

# p_cshr_tx <- ggplot(subset(cshr, r == "TX"), aes(val,egt,fill=g)) +
#   geom_bar(stat = "identity", color = "black") +
#   scale_fill_brewer(palette = "Set2") +
#   theme_bw() + 
#   theme(legend.position = "bottom") +
#   theme(axis.text.x = element_text(size = 6)) +
#   theme(axis.text.y = element_text(size = 7)) +
#   theme(legend.text=element_text(size=6)) +
#   facet_wrap(~r) +
#   labs(title="U.S. Benchmark Input Demand by Generation Technology",
#        subtitle="Share of total cost",
#        x = "Share of total cost",
#        y = "Generation Fuel Source",
#        fill = "Input")
# p_cshr_tx

ggsave(filename=file.path(plots_path,paste0(scn,"_",reg),paste0("[",scn,"_",reg,"]","p_cshr.png")),p_cshr,width = 6,height = 4.5)
# ggsave(filename=file.path(plots_path,paste0(scn,"_",reg),paste0("[",scn,"_",reg,"]","p_cshr_tx.png")),p_cshr_tx,width = 6,height = 4.5)

# egtshr = subset(egtshr,g %in% goods_acr)
# egtshr$g = factor(egtshr$g, levels=goods_acr, labels=goods_full)
egtshr = subset(egtshr, r %in% regions)
egtshr$r = factor(egtshr$r, levels = regions_ord, labels = regions)

egtshr = subset(egtshr, egt %in% egt_acr)
egtshr$egt = factor(egtshr$egt, levels = egt_acr, labels = egt_full)

p_egtshr <- ggplot(egtshr, aes(val,r,fill=egt)) +
  geom_bar(stat = "identity", color = "black") +
  scale_fill_brewer(palette = "Set3") +
  theme_bw() + 
  theme(legend.position = "bottom") +
  theme(axis.text.x = element_text(size = 8)) +
  theme(axis.text.y = element_text(size = 7)) +
  theme(legend.text=element_text(size=6)) +
  # facet_wrap(~r) +
  labs(title="U.S. Benchmark Generation Share by Tech",
       subtitle="Share of total",
       x = "Share of total",
       y = "State",
       fill = "Generation Fuel Source")
p_egtshr

ggsave(filename=file.path(plots_path,paste0(scn,"_",reg),paste0("[",scn,"_",reg,"]","p_egtshr.png")),p_egtshr,width = 6,height = 4.5)


#####
# Plot Utility (ele sector) Electricity Generation by technology
#####
ele_sup = subset(r_elec,var == "supply (TWh)")
ele_sup$egt = factor(ele_sup$egt, levels=egt_acr, labels=egt_full)

ele_sup_us = subset(ele_sup,r=="all")
ele_sup = subset(ele_sup,r %in% regions)
head(ele_sup)

p_ele_sup_us <- ggplot(ele_sup_us, aes(t,val,fill=egt)) +
  geom_area(colour="black") +
#  plot_specs +
#  facet_wrap(~r) +
  scale_fill_brewer(palette = "Set3") +
  labs(title="Electricity sector supply by generation technology",
       subtitle=paste0("[",scn,"] Output at benchmark year prices (P_bench*Q)"),
       y = "Billion USD",
       x = "Year",
       fill = "Generation Source")
p_ele_sup_us


p_ele_sup <- ggplot(ele_sup, aes(t,val,fill=egt)) +
  geom_area(colour="black") +
  plot_specs +
  facet_wrap(~r) +
  scale_fill_brewer(palette = "Set3") +
  labs(title="Electricity sector supply by generation technology",
       subtitle=paste0("[",scn,"] Output at benchmark year prices (P_bench*Q)"),
       y = "Billion USD",
       x = "Year",
       fill = "Generation Source")
p_ele_sup
p_ele_sup_free <- p_ele_sup + 
  facet_wrap(~r, scales = "free_y")


ggsave(filename=file.path(plots_path,paste0(scn,"_",reg),paste0("[",scn,"_",reg,"]","p_ele_sup.png")),p_ele_sup,width = 6,height = 4.5)
ggsave(filename=file.path(plots_path,paste0(scn,"_",reg),paste0("[",scn,"_",reg,"]","p_ele_sup_free.png")),p_ele_sup_free,width = 6,height = 4.5)
ggsave(filename=file.path(plots_path,paste0(scn,"_",reg),paste0("[",scn,"_",reg,"]","p_ele_sup_us.png")),p_ele_sup_us,width = 6,height = 4.5)

vgen_sup = subset(ele_sup,cat=="vgen")

p_vgen_sup <- ggplot(vgen_sup, aes(t,val,fill=egt)) +
  geom_area(colour="black") +
  plot_specs +
  facet_wrap(~r) +
  scale_fill_brewer(palette = "Set3") +
  labs(title="Electricity sector supply by generation technology",
       subtitle=paste0("[",scn,"] Output at benchmark year prices (P_bench*Q)"),
       y = "Billion USD",
       x = "Year",
       fill = "Generation Source")
p_vgen_sup

p_vgen_sup_free <- p_vgen_sup +
  facet_wrap(~r, scales = "free_y")
  

ggsave(filename=file.path(plots_path,paste0(scn,"_",reg),paste0("[",scn,"_",reg,"]","p_vgen_sup.png")),p_vgen_sup,width = 6,height = 4.5)
ggsave(filename=file.path(plots_path,paste0(scn,"_",reg),paste0("[",scn,"_",reg,"]","p_vgen_sup_free.png")),p_vgen_sup_free,width = 6,height = 4.5)

#####
# Plot emissions
#####

dco2_s = subset(r_rep,var=="DCO2_SECT")

# convert to billion tons from million tons
dco2_s$val = dco2_s$val / 1000

dco2_s$g = factor(dco2_s$g, levels=sect_acr, labels=sect_full)

dco2_s_all = subset(dco2_s, var == "DCO2_SECT" & r == "all" & g != "all")
dco2_s_reg = subset(dco2_s, var == "DCO2_SECT" & r %in% regions & g != "all")

p_dco2_s_all <- ggplot(dco2_s_all, aes(t,val,fill=g)) +
  geom_area(colour="black") +
  theme_bw() +
#  facet_wrap(~r, scales = 'free_y') +
  scale_fill_brewer(palette = "Set3") +
  labs(title="CO2 Emissions by Sector over the Time Horizon",
       subtitle=paste0("[",scn,"]","Billion Tons CO2"),
       y = "Billion Tons CO2",
       x = "Year",
       fill = "Sector")
p_dco2_s_all


p_dco2_s_reg <- ggplot(dco2_s_reg, aes(t,val,fill=g)) +
  geom_area(colour="black") +
  plot_specs +
  facet_wrap(~r, scales = 'free_y') +
  scale_fill_brewer(palette = "Set3") +
  labs(title="CO2 Emissions by Sector over the Time Horizon",
       subtitle=paste0("[",scn,"]","Billion Tons CO2"),
       y = "Billion Tons CO2",
       x = "Year",
       fill = "Sector")
p_dco2_s_reg


ggsave(filename=file.path(plots_path,paste0(scn,"_",reg),paste0("[",scn,"_",reg,"]","p_dco2_s_all.png")),p_dco2_s_all,width = 6,height = 4.5)
ggsave(filename=file.path(plots_path,paste0(scn,"_",reg),paste0("[",scn,"_",reg,"]","p_dco2_s_reg.png")),p_dco2_s_reg,width = 6,height = 4.5)

rep_pcarb = subset(r_rep,var=="PCO2")

p_pcarb <- ggplot(rep_pcarb, aes(t,val)) +
  geom_line() +
  plot_specs +
  labs(title="U.S. CO2 Emissions Price",
       subtitle="USD/Ton CO2",
       y = "USD/Ton CO2",
       x = "Year")
p_pcarb

ggsave(filename=file.path(plots_path,paste0(scn,"_",reg),paste0("[",scn,"_",reg,"]","p_pcarb.png")),p_pcarb,width = 6,height = 4.5)

#####
# Plot welfare decomposition
#####

# dco2_s = subset(r_rep,var=="DCO2_SECT")
# dco2_s$g = factor(dco2_s$g, levels=sect_acr, labels=sect_full)
# 
# dco2_s_all = subset(dco2_s, var == "DCO2_SECT" & r == "all" & g != "all")
# dco2_s_reg = subset(dco2_s, var == "DCO2_SECT" & r %in% regions & g != "all")

wdecomp_us = subset(r_wdecomp,units=="$" & r == "total" & var != "total")
wdecomp_reg = subset(r_wdecomp,units=="$" & r %in% regions & var != "total")
wdecomp_us_pct = subset(r_wdecomp,units=="%" & r == "total" & var != "total")

p_wdecomp_us <- ggplot(wdecomp_us, aes(t,val,fill=var)) +
  geom_area(colour="black") +
  plot_specs +
  facet_wrap(~h, scales = 'free_y') +
  scale_fill_brewer(palette = "Set3") +
  labs(title="Welfare decomposition",
       subtitle=paste0("[",scn,"]","Billion USD"),
       y = "Billion USD",
       x = "Year",
       fill = "Welfare Income")
p_wdecomp_us

p_wdecomp_us_pct <- ggplot(wdecomp_us_pct, aes(t,val,fill=var)) +
  geom_area(colour="black") +
  plot_specs +
  facet_wrap(~h, scales = 'free_y') +
  scale_fill_brewer(palette = "Set3") +
  labs(title="Welfare decomposition",
       subtitle=paste0("[",scn,"]","Percent (%)"),
       y = "%",
       x = "Year",
       fill = "Welfare Income")
p_wdecomp_us_pct

ggsave(filename=file.path(plots_path,paste0(scn,"_",reg),paste0("[",scn,"_",reg,"]","p_wdecomp_us.png")),p_wdecomp_us,width = 6,height = 4.5)
ggsave(filename=file.path(plots_path,paste0(scn,"_",reg),paste0("[",scn,"_",reg,"]","p_wdecomp_us_pct.png")),p_wdecomp_us_pct,width = 6,height = 4.5)


# p_wdecomp_reg <- ggplot(wdecomp_reg, aes(t,val,fill=var)) +
#   geom_area(colour="black") +
#   theme_bw() +
#   facet_wrap(~r, scales = 'free_y') +
#   scale_fill_brewer(palette = "Set3") +
#   labs(title="GDP decomposition",
#        subtitle=paste0("[",scn,"]","Billion USD"),
#        y = "Billion USD",
#        x = "Year",
#        fill = "GDP Income")
# p_wdecomp_reg

#####
# Plot GDP decomposition
#####

gdp_us = subset(r_gdp,r == "total" & var != "total")
gdp_reg = subset(r_gdp,r %in% regions & var != "total")

p_gdp_us <- ggplot(gdp_us, aes(t,val,fill=var)) +
  geom_area(colour="black") +
  plot_specs +
  #  facet_wrap(~r, scales = 'free_y') +
  scale_fill_brewer(palette = "Set3") +
  labs(title="GDP decomposition",
       subtitle=paste0("[",scn,"]","Billion USD"),
       y = "Billion USD",
       x = "Year",
       fill = "GDP Income")
p_gdp_us

p_gdp_reg <- ggplot(gdp_reg, aes(t,val,fill=var)) +
  geom_area(colour="black") +
  plot_specs + 
  facet_wrap(~r, scales = 'free_y') +
  scale_fill_brewer(palette = "Set3") +
  labs(title="GDP decomposition",
       subtitle=paste0("[",scn,"]","Billion USD"),
       y = "Billion USD",
       x = "Year",
       fill = "GDP Income")
p_gdp_reg

ggsave(filename=file.path(plots_path,paste0(scn,"_",reg),paste0("[",scn,"_",reg,"]","p_gdp_us.png")),p_gdp_us,width = 6,height = 4.5)
ggsave(filename=file.path(plots_path,paste0(scn,"_",reg),paste0("[",scn,"_",reg,"]","p_gdp_reg.png")),p_gdp_reg,width = 6,height = 4.5)


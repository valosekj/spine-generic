#!/bin/bash
# 
# Process data.
# 
# Run script from the subject's folder.
# 
# Dependencies: 
# - SCT v3.2.0 and higher.
# - (fsleyes for visualization)
# 
# Authors: Julien Cohen-Adad, Stephanie Alley


# t1
# ===========================================================================================
cd t1
# Check if manual segmentation already exists
if [ -e "t1_seg_manual.nii.gz" ]; then
  file_seg="t1_seg_manual.nii.gz"
else
  echo "Segment spinal cord"
  sct_propseg -i t1.nii.gz -c t1
  file_seg="t1_seg.nii.gz"
  # Check segmentation results and do manual corrections if necessary
  echo "Check segmentation and do manual correction if necessary, then save modified segmentation as t1_seg_manual.nii.gz"
  fsleyes t1.nii.gz -cm greyscale t1_seg.nii.gz -cm red -a 70.0 &
fi
# Check if manual labels already exists
if [ ! -e "label_disc.nii.gz" ]; then
  echo "Create manual labels."
  sct_label_utils -i t1.nii.gz -create-viewer 3,4,5,6,7,8 -o label_disc.nii.gz -msg "Place labels at the posterior tip of each inter-vertebral disc. E.g. Label 3: C2/C3, Label 4: C3/C4, etc."
fi
echo "Flatten t1 scan (to make nice figures)"
sct_flatten_sagittal -i t1.nii.gz -s ${file_seg}
# Go to parent folder
cd ..


# t2
# ===========================================================================================
cd t2
# Check if manual segmentation already exists
if [ -e "t2_seg_manual.nii.gz" ]; then
  file_seg="t2_seg_manual.nii.gz"
else
  echo "Segment spinal cord"
  sct_propseg -i t2.nii.gz -c t2
  file_seg="t2_seg.nii.gz"
  # Check segmentation results and do manual corrections if necessary
  echo "Check segmentation and do manual correction if necessary, then save modified segmentation as t2_seg_manual.nii.gz"
  fsleyes t2.nii.gz -cm greyscale t2_seg.nii.gz -cm red -a 70.0 &
fi
# Check if manual labels already exists
if [ ! -e "label_disc.nii.gz" ]; then
  echo "Create manual labels."
  sct_label_utils -i t2.nii.gz -create-viewer 3,4,5,6,7,8 -o label_disc.nii.gz -msg "Place labels at the posterior tip of each inter-vertebral disc. E.g. Label 3: C2/C3, Label 4: C3/C4, etc."
fi
echo "Flatten t2 scan (to make nice figures"
sct_flatten_sagittal -i t2.nii.gz -s ${file_seg}
# Go to parent folder
cd ..


# dmri
# ===========================================================================================
cd dmri
# Separate b=0 and DW images
sct_dmri_separate_b0_and_dwi -i dmri.nii.gz -bvec bvecs.txt
# Segment cord (1st pass)
sct_propseg -i dwi_mean.nii.gz -c dwi
# Create mask to aid in motion correction and for faster processing
sct_create_mask -i dwi_mean.nii.gz -p centerline,dwi_mean_seg.nii.gz -size 30mm
# Crop data for faster processing
sct_crop_image -i dmri.nii.gz -m mask_dwi_mean.nii.gz -o dmri_crop.nii.gz
# Motion correction
sct_dmri_moco -i dmri_crop.nii.gz -bvec bvecs.txt -x spline
# Check if manual segmentation already exists
if [ -e "dwi_moco_mean_seg_manual.nii.gz" ]; then
  file_seg="dwi_moco_mean_seg_manual.nii.gz"
else
  # Segment cord (2nd pass, after motion correction)
  sct_propseg -i dwi_moco_mean.nii.gz -c dwi
  file_seg="dwi_moco_mean_seg.nii.gz"
  # Check segmentation results and do manual corrections if necessary, then save modified segmentation as dwi_moco_mean_seg_manual.nii.gz"
  echo "Check segmentation and do manual correction if necessary, then save modified segmentation as t2_seg_manual.nii.gz"
  fsleyes dwi_moco_mean.nii.gz -cm greyscale dwi_moco_mean_seg.nii.gz -cm red -a 70.0 &
fi
# create dummy label with value=4
sct_label_utils -i dwi_moco_mean.nii.gz -create 1,1,1,4 -o label_dummy.nii.gz
# use dummy label to import labels from t1 and keep only value=4 label
sct_label_utils -i ../t1/label_disc.nii.gz -remove label_dummy.nii.gz -o label_disc.nii.gz
# Register template to dwi
# Tips: Only use segmentations.
# Tips: First step: slicereg based on images, with large smoothing to capture potential motion between anatomical and dmri.
# Tips: Second step: bpslinesyn in order to adapt the shape of the cord to the dmri modality (in case there are distortions between anatomical and dmri).
sct_register_to_template -i dwi_moco_mean.nii.gz -s ${file_seg} -ldisc label_disc.nii.gz -ref subject -c t1 -param step=1,type=seg,algo=centermass:step=2,type=seg,algo=bsplinesyn,slicewise=1,iter=3
# Rename warping field for clarity
mv warp_template2anat.nii.gz warp_template2dmri.nii.gz
# Warp template and white matter atlas
sct_warp_template -d dwi_moco_mean.nii.gz -w warp_template2dmri.nii.gz
# Compute DTI
sct_dmri_compute_dti -i dmri_crop_moco.nii.gz -bvec bvecs.txt -bval bvals.txt -method restore
# Go to parent folder
cd ..


# mt
# ===========================================================================================
cd mt
# Check if manual segmentation already exists
if [ -e "t1w_seg_manual.nii.gz" ]; then
  file_seg="t1w_seg_manual.nii.gz"
else
  # Segment cord (2nd pass, after motion correction)
  sct_propseg -i t1w.nii.gz -c t1
  file_seg="t1w_seg.nii.gz"
  # Check segmentation results and do manual corrections if necessary, then save modified segmentation as dwi_moco_mean_seg_manual.nii.gz"
  echo "Check segmentation and do manual correction if necessary, then save modified segmentation as t2_seg_manual.nii.gz"
  fsleyes t1w.nii.gz -cm greyscale t1w_seg.nii.gz -cm red -a 70.0 &
fi
# Create mask
sct_create_mask -i t1w.nii.gz -p centerline,t1w_seg.nii.gz -size 35mm
# Crop data for faster processing
sct_crop_image -i t1w.nii.gz -m mask_t1w.nii.gz -o t1w_crop.nii.gz
# Register mt0->t1w
# Tips: here we only use rigid transformation because both images have very similar sequence parameters. We don't want to use SyN/BSplineSyN to avoid introducing spurious deformations.
sct_register_multimodal -i mt0.nii.gz -d t1w_crop.nii.gz -param step=1,type=im,algo=rigid,slicewise=1,metric=CC -x spline
# Register mt1->t1w
sct_register_multimodal -i mt1.nii.gz -d t1w_crop.nii.gz -param step=1,type=im,algo=rigid,slicewise=1,metric=CC -x spline
# create dummy label with value=4
sct_label_utils -i t1w_crop.nii.gz -create 1,1,1,4 -o label_dummy.nii.gz
# use dummy label to import labels from t1 and keep only value=4 label
sct_label_utils -i ../t1/label_disc.nii.gz -remove label_dummy.nii.gz -o label_disc.nii.gz
# Register template->t1w
sct_register_to_template -i t1w_crop.nii.gz -s ${file_seg} -ldisc label_disc.nii.gz -ref subject -c t1 -param step=1,type=seg,algo=centermass:step=2,type=seg,algo=bsplinesyn,slicewise=1,iter=3
# Rename warping field for clarity
mv warp_template2anat.nii.gz warp_template2mt.nii.gz
# Warp template
sct_warp_template -d t1w_crop.nii.gz -w warp_template2mt.nii.gz -a 0
# Compute MTR
sct_compute_mtr -mt0 mt0_reg.nii.gz -mt1 mt1_reg.nii.gz
# Compute MTsat
# TODO
# sct_compute_mtsat -mt mt1_crop.nii.gz -pd mt0_reg.nii.gz -t1 t1w_reg.nii.gz -trmt 30 -trpd 30 -trt1 15 -famt 9 -fapd 9 -fat1 15
# Go to parent folder
cd ..



# # ===========================================================================================================
# : "
# # gre-me
# cd gre-me

# #Segment cord
# echo "Segmenting gre-me cord"
# sct_propseg -i gre-me.nii.gz -c t2_seg

# # Add QC here

# # Create a file, labels.nii.gz, that will be used for template registration
# # Manually create labels at C3 (3) and C4 (4) by clicking on the center of the respective vertebral level using the interactive window
# echo "Creating gre-me labels"
# sct_label_utils -i gre-me.nii.gz -create-viewer 3,4

# # Create mask for faster processing
# sct_create_mask -i gre-me.nii.gz -p centerline,gre-me_seg.nii.gz -size 40mm -o mask_cord.nii.gz

# # Crop data for faster processing
# echo "Cropping gre-me data"
# sct_crop_image -i gre-me.nii.gz -m mask_cord.nii.gz -o gre-me_crop.nii.gz
# sct_crop_image -i gre-me_seg.nii.gz -m mask_cord.nii.gz -o gre-me_seg_crop.nii.gz
# sct_crop_image -i labels.nii.gz -m mask_cord.nii.gz -o labels_crop.nii.gz

# # Create vertebral levels for the cord segmentation (t1 and t2 are the only contrast options available)
# # Initialize manually by clicking on the C2-C3 disc using the interactive window
# echo "Creating vertebral levels for gre-me"
# sct_label_vertebrae -i gre-me_crop.nii.gz -s gre-me_seg_crop -c t2 -initc2

# # Register to template
# echo "Registering gre-me to template"
# sct_register_to_template -i gre-me_crop.nii.gz -s gre-me_seg_crop.nii.gz -c t2s -l labels_crops.nii.gz

# # Warp template without the white matter atlas
# echo "Warping template to gre-me"
# sct_warp_template -d gre-me_crop.nii.gz -w warp_template2anat.nii.gz -a 0

# # Segment the gray matter of the gre-me
# echo "Segmenting gre-me gray matter"
# sct_segment_graymatter -i gre-me_crop.nii.gz -s gre-me_seg_crop.nii.gz

# # Go to parent folder
# cd ..

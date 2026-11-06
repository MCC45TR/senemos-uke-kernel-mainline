static int fastrpc_cb_probe(struct platform_device *pdev)
{
	struct fastrpc_channel_ctx *cctx;
	struct fastrpc_session_ctx *sess;
	struct device *dev = &pdev->dev;
	int i, sessions = 0;
	unsigned long flags;
	u32 dma_bits;
	u32 sid = 0;
	int rc;

	cctx = dev_get_drvdata(dev->parent);
	if (!cctx)
		return -EINVAL;

	of_property_read_u32(dev->of_node, "qcom,nsessions", &sessions);
	if (of_property_read_u32(dev->of_node, "reg", &sid))
		dev_info(dev, "FastRPC Session ID not specified in DT\n");

	/* Publish no session until its device has a usable DMA mask. */
	dma_bits = cctx->soc_data->dma_addr_bits_default;
	if (cctx->domain_id == CDSP_DOMAIN_ID)
		dma_bits = cctx->soc_data->dma_addr_bits_cdsp;
	rc = dma_set_mask(dev, DMA_BIT_MASK(dma_bits));
	if (rc) {
		dev_err(dev, "%u-bit DMA enable failed\n", dma_bits);
		return rc;
	}

	spin_lock_irqsave(&cctx->lock, flags);
	if (cctx->sesscount >= FASTRPC_MAX_SESSIONS) {
		spin_unlock_irqrestore(&cctx->lock, flags);
		dev_err(&pdev->dev, "too many sessions\n");
		return -ENOSPC;
	}
	sess = &cctx->session[cctx->sesscount++];
	sess->used = false;
	sess->valid = true;
	sess->dev = dev;
	dev_set_drvdata(dev, sess);
	sess->sid = sid;

	if (sessions > 0) {
		struct fastrpc_session_ctx *dup_sess;

		for (i = 1; i < sessions; i++) {
			if (cctx->sesscount >= FASTRPC_MAX_SESSIONS)
				break;
			dup_sess = &cctx->session[cctx->sesscount++];
			memcpy(dup_sess, sess, sizeof(*dup_sess));
		}
	}
	spin_unlock_irqrestore(&cctx->lock, flags);

	return 0;
}
